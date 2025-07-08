require "test_helper"
require "ostruct"

class DataSourceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @data_source = DataSource.new(
      name: "weather_test",
      source_type: "weather",
      api_endpoint: "https://api.openweathermap.org/data/2.5/weather",
      api_key: "test_key",
      configuration: { "default_city" => "London", "cache_duration" => 60 },
      user: @user,
      active: true
    )
  end

  test "should be valid with valid attributes" do
    assert @data_source.valid?
  end

  test "should require name" do
    @data_source.name = nil
    assert_not @data_source.valid?
    assert_includes @data_source.errors[:name], "can't be blank"
  end

  test "should require source_type" do
    @data_source.source_type = nil
    assert_not @data_source.valid?
    assert_includes @data_source.errors[:source_type], "can't be blank"
  end

  test "should require api_endpoint" do
    @data_source.api_endpoint = nil
    assert_not @data_source.valid?
    assert_includes @data_source.errors[:api_endpoint], "can't be blank"
  end

  test "should require user" do
    @data_source.user = nil
    assert_not @data_source.valid?
    assert_includes @data_source.errors[:user], "must exist"
  end

  test "should validate source_type inclusion" do
    @data_source.source_type = "invalid"
    assert_not @data_source.valid?
    assert_includes @data_source.errors[:source_type], "is not included in the list"
  end

  test "should validate unique name per user" do
    @data_source.save!
    
    duplicate = DataSource.new(
      name: "weather_test",
      source_type: "stock",
      api_endpoint: "https://example.com",
      user: @user
    )
    
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should allow same name for different users" do
    @data_source.save!
    
    other_user = users(:two)
    other_data_source = DataSource.new(
      name: "weather_test",
      source_type: "stock",
      api_endpoint: "https://example.com",
      user: other_user
    )
    
    assert other_data_source.valid?
  end

  test "should encrypt api_key" do
    @data_source.save!
    
    # The encrypted attribute should not be readable
    assert_not_equal "test_key", @data_source.read_attribute(:api_key)
    
    # But the decrypted value should be accessible
    assert_equal "test_key", @data_source.api_key
  end

  test "scope active should return only active data sources" do
    @data_source.save!
    inactive_source = DataSource.create!(
      name: "inactive_test",
      source_type: "stock",
      api_endpoint: "https://example.com",
      user: @user,
      active: false
    )
    
    active_sources = DataSource.active
    assert_includes active_sources, @data_source
    assert_not_includes active_sources, inactive_source
  end

  test "should fetch weather data" do
    @data_source.source_type = "weather"
    @data_source.save!

    # Mock the weather service
    mock_service = Minitest::Mock.new
    mock_result = OpenStruct.new(success?: true, data: { "temp" => 20 })
    mock_service.expect(:fetch, mock_result, [{}])
    
    WeatherService.stub(:new, mock_service) do
      result = @data_source.fetch_data
      assert result.success?
      assert_equal 20, result.data["temp"]
    end
    
    mock_service.verify
  end

  test "should fetch stock data" do
    @data_source.source_type = "stock"
    @data_source.save!

    mock_service = Minitest::Mock.new
    mock_result = OpenStruct.new(success?: true, data: { "price" => 150.00 })
    mock_service.expect(:fetch, mock_result, [{}])
    
    StockService.stub(:new, mock_service) do
      result = @data_source.fetch_data
      assert result.success?
      assert_equal 150.00, result.data["price"]
    end
    
    mock_service.verify
  end

  test "should fetch news data" do
    @data_source.source_type = "news"
    @data_source.save!

    mock_service = Minitest::Mock.new
    mock_result = OpenStruct.new(success?: true, data: { "articles" => [] })
    mock_service.expect(:fetch, mock_result, [{}])
    
    NewsService.stub(:new, mock_service) do
      result = @data_source.fetch_data
      assert result.success?
      assert_equal [], result.data["articles"]
    end
    
    mock_service.verify
  end

  test "should fetch location data" do
    @data_source.source_type = "location"
    @data_source.save!

    mock_service = Minitest::Mock.new
    mock_result = OpenStruct.new(success?: true, data: { "city" => "London" })
    mock_service.expect(:fetch, mock_result, [{}])
    
    LocationService.stub(:new, mock_service) do
      result = @data_source.fetch_data
      assert result.success?
      assert_equal "London", result.data["city"]
    end
    
    mock_service.verify
  end

  test "should fetch custom data" do
    @data_source.source_type = "custom"
    @data_source.save!

    mock_service = Minitest::Mock.new
    mock_result = OpenStruct.new(success?: true, data: { "custom" => "data" })
    mock_service.expect(:fetch, mock_result, [{}])
    
    CustomApiService.stub(:new, mock_service) do
      result = @data_source.fetch_data
      assert result.success?
      assert_equal "data", result.data["custom"]
    end
    
    mock_service.verify
  end

  test "needs_refresh should return true when no data points exist" do
    @data_source.save!
    assert @data_source.needs_refresh?
  end

  test "needs_refresh should return true when latest data point is expired" do
    @data_source.save!
    @data_source.data_points.create!(
      key: "test",
      value: { "temp" => 20 },
      fetched_at: 2.hours.ago,
      expires_at: 1.hour.ago
    )
    
    assert @data_source.needs_refresh?
  end

  test "needs_refresh should return false when latest data point is not expired" do
    @data_source.save!
    @data_source.data_points.create!(
      key: "test",
      value: { "temp" => 20 },
      fetched_at: 1.hour.ago,
      expires_at: 1.hour.from_now
    )
    
    assert_not @data_source.needs_refresh?
  end

  test "cached_data should return cached value when not expired" do
    @data_source.save!
    data_point = @data_source.data_points.create!(
      key: "weather_london",
      value: { "temp" => 20 },
      fetched_at: 1.hour.ago,
      expires_at: 1.hour.from_now
    )
    
    result = @data_source.cached_data("weather_london")
    assert_equal({ "temp" => 20 }, result)
  end

  test "cached_data should fetch new data when cache is expired" do
    @data_source.save!
    
    # Create expired data point
    @data_source.data_points.create!(
      key: "weather_london",
      value: { "temp" => 15 },
      fetched_at: 2.hours.ago,
      expires_at: 1.hour.ago
    )
    
    # Mock the service to return new data
    mock_service = Minitest::Mock.new
    mock_result = OpenStruct.new(
      success?: true, 
      data: { "temp" => 25 },
      metadata: { "source" => "api" }
    )
    mock_service.expect(:fetch, mock_result, [{}])
    
    WeatherService.stub(:new, mock_service) do
      result = @data_source.cached_data("weather_london")
      assert_equal({ "temp" => 25 }, result)
    end
    
    mock_service.verify
  end

  test "associations should work correctly" do
    @data_source.save!
    
    # Test data_points association
    data_point = @data_source.data_points.create!(
      key: "test",
      value: { "data" => "test" },
      fetched_at: Time.current,
      expires_at: 1.hour.from_now
    )
    
    assert_includes @data_source.data_points, data_point
    
    # Test template_data_sources association
    template = @user.pdf_templates.create!(
      name: "Test Template",
      description: "Test",
      template_content: "<h1>Test</h1>",
      active: true
    )
    
    template_data_source = @data_source.template_data_sources.create!(
      pdf_template: template
    )
    
    assert_includes @data_source.template_data_sources, template_data_source
    assert_includes @data_source.pdf_templates, template
  end

  test "destroying data source should destroy dependent records" do
    @data_source.save!
    
    data_point = @data_source.data_points.create!(
      key: "test",
      value: { "data" => "test" },
      fetched_at: Time.current,
      expires_at: 1.hour.from_now
    )
    
    template = @user.pdf_templates.create!(
      name: "Test Template",
      description: "Test",
      template_content: "<h1>Test</h1>",
      active: true
    )
    
    template_data_source = @data_source.template_data_sources.create!(
      pdf_template: template
    )
    
    data_point_id = data_point.id
    template_data_source_id = template_data_source.id
    
    @data_source.destroy
    
    assert_not DataPoint.exists?(data_point_id)
    assert_not TemplateDataSource.exists?(template_data_source_id)
  end
end