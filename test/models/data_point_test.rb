require "test_helper"

class DataPointTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @data_source = DataSource.create!(
      name: "weather_test",
      source_type: "weather",
      api_endpoint: "https://api.openweathermap.org/data/2.5/weather",
      api_key: "test_key",
      user: @user,
      active: true
    )
    @data_point = DataPoint.new(
      data_source: @data_source,
      key: "weather_london",
      value: { "temp" => 20, "condition" => "sunny" },
      fetched_at: Time.current,
      expires_at: 1.hour.from_now,
      metadata: { "source" => "openweathermap" }
    )
  end

  test "should be valid with valid attributes" do
    assert @data_point.valid?
  end

  test "should require data_source" do
    @data_point.data_source = nil
    assert_not @data_point.valid?
    assert_includes @data_point.errors[:data_source], "must exist"
  end

  test "should require key" do
    @data_point.key = nil
    assert_not @data_point.valid?
    assert_includes @data_point.errors[:key], "can't be blank"
  end

  test "should require value" do
    @data_point.value = nil
    assert_not @data_point.valid?
    assert_includes @data_point.errors[:value], "can't be blank"
  end

  test "should require fetched_at" do
    @data_point.fetched_at = nil
    assert_not @data_point.valid?
    assert_includes @data_point.errors[:fetched_at], "can't be blank"
  end

  test "should require expires_at" do
    @data_point.expires_at = nil
    assert_not @data_point.valid?
    assert_includes @data_point.errors[:expires_at], "can't be blank"
  end

  test "should store value as JSON" do
    @data_point.save!
    
    # Reload from database to ensure JSON serialization works
    reloaded = DataPoint.find(@data_point.id)
    assert_equal 20, reloaded.value["temp"]
    assert_equal "sunny", reloaded.value["condition"]
  end

  test "should store metadata as JSON" do
    @data_point.save!
    
    # Reload from database to ensure JSON serialization works
    reloaded = DataPoint.find(@data_point.id)
    assert_equal "openweathermap", reloaded.metadata["source"]
  end

  test "should handle complex nested JSON in value" do
    complex_value = {
      "weather" => {
        "main" => {
          "temp" => 20.5,
          "feels_like" => 18.2,
          "humidity" => 65
        },
        "description" => "partly cloudy",
        "wind" => {
          "speed" => 3.2,
          "direction" => "NW"
        }
      },
      "location" => {
        "city" => "London",
        "country" => "UK",
        "coordinates" => [51.5074, -0.1278]
      },
      "timestamp" => Time.current.iso8601
    }
    
    @data_point.value = complex_value
    @data_point.save!
    
    reloaded = DataPoint.find(@data_point.id)
    assert_equal 20.5, reloaded.value["weather"]["main"]["temp"]
    assert_equal "London", reloaded.value["location"]["city"]
    assert_equal [51.5074, -0.1278], reloaded.value["location"]["coordinates"]
  end

  test "should validate expires_at is after fetched_at" do
    @data_point.fetched_at = Time.current
    @data_point.expires_at = 1.hour.ago
    
    assert_not @data_point.valid?
    assert_includes @data_point.errors[:expires_at], "must be after fetched_at"
  end

  test "should allow expires_at to be same as fetched_at" do
    time = Time.current
    @data_point.fetched_at = time
    @data_point.expires_at = time
    
    assert @data_point.valid?
  end

  test "should belong to data_source" do
    @data_point.save!
    assert_equal @data_source, @data_point.data_source
  end

  test "should be destroyed when data_source is destroyed" do
    @data_point.save!
    data_point_id = @data_point.id
    
    @data_source.destroy
    
    assert_not DataPoint.exists?(data_point_id)
  end

  test "should scope by data_source and key" do
    @data_point.save!
    
    # Create another data point for same data source but different key
    other_data_point = DataPoint.create!(
      data_source: @data_source,
      key: "weather_paris",
      value: { "temp" => 18 },
      fetched_at: Time.current,
      expires_at: 1.hour.from_now
    )
    
    # Create data point for different data source
    other_data_source = DataSource.create!(
      name: "stock_test",
      source_type: "stock",
      api_endpoint: "https://api.example.com",
      user: @user
    )
    
    different_source_point = DataPoint.create!(
      data_source: other_data_source,
      key: "weather_london",
      value: { "price" => 100 },
      fetched_at: Time.current,
      expires_at: 1.hour.from_now
    )
    
    # Test scoping
    london_weather_points = DataPoint.where(data_source: @data_source, key: "weather_london")
    assert_includes london_weather_points, @data_point
    assert_not_includes london_weather_points, other_data_point
    assert_not_includes london_weather_points, different_source_point
  end

  test "should order by fetched_at descending by default" do
    # Create an older data point
    older_point = DataPoint.create!(
      data_source: @data_source,
      key: "weather_test_old",
      value: { "temp" => 15 },
      fetched_at: 2.hours.ago,
      expires_at: 1.hour.ago
    )
    
    # Create a middle data point
    middle_point = DataPoint.create!(
      data_source: @data_source,
      key: "weather_test_middle",
      value: { "temp" => 20 },
      fetched_at: 1.hour.ago,
      expires_at: 1.hour.from_now
    )
    
    # Create a newer data point
    newer_point = DataPoint.create!(
      data_source: @data_source,
      key: "weather_test_new",
      value: { "temp" => 25 },
      fetched_at: 1.minute.ago,
      expires_at: 1.hour.from_now
    )
    
    points = @data_source.data_points.order(fetched_at: :desc)
    assert_equal newer_point, points.first
    assert_equal middle_point, points.second
    assert_equal older_point, points.third
  end

  test "should find unexpired data points" do
    # Create expired data point
    expired_point = DataPoint.create!(
      data_source: @data_source,
      key: "expired_data",
      value: { "temp" => 15 },
      fetched_at: 2.hours.ago,
      expires_at: 1.hour.ago
    )
    
    # Create valid data point
    @data_point.save!
    
    unexpired_points = DataPoint.where('expires_at > ?', Time.current)
    assert_includes unexpired_points, @data_point
    assert_not_includes unexpired_points, expired_point
  end

  test "should handle nil metadata gracefully" do
    @data_point.metadata = nil
    @data_point.save!
    
    reloaded = DataPoint.find(@data_point.id)
    assert_nil reloaded.metadata
  end

  test "should handle empty value hash" do
    @data_point.value = {}
    assert @data_point.valid?
    
    @data_point.save!
    reloaded = DataPoint.find(@data_point.id)
    assert_equal({}, reloaded.value)
  end

  test "should validate value is not empty array" do
    @data_point.value = []
    assert_not @data_point.valid?
    assert_includes @data_point.errors[:value], "can't be blank"
  end

  test "should allow string values to be stored" do
    @data_point.value = { "message" => "Hello, World!", "status" => "success" }
    @data_point.save!
    
    reloaded = DataPoint.find(@data_point.id)
    assert_equal "Hello, World!", reloaded.value["message"]
    assert_equal "success", reloaded.value["status"]
  end

  test "should allow boolean values to be stored" do
    @data_point.value = { "is_active" => true, "has_error" => false }
    @data_point.save!
    
    reloaded = DataPoint.find(@data_point.id)
    assert_equal true, reloaded.value["is_active"]
    assert_equal false, reloaded.value["has_error"]
  end

  test "should allow array values to be stored" do
    @data_point.value = {
      "temperatures" => [20, 21, 19, 22],
      "cities" => ["London", "Paris", "Berlin"]
    }
    @data_point.save!
    
    reloaded = DataPoint.find(@data_point.id)
    assert_equal [20, 21, 19, 22], reloaded.value["temperatures"]
    assert_equal ["London", "Paris", "Berlin"], reloaded.value["cities"]
  end
end