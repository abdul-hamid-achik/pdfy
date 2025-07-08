require "test_helper"

class FetchDataSourceJobTest < ActiveJob::TestCase
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
  end

  test "should perform job successfully" do
    # Mock the weather API response
    mock_weather_response = {
      "main" => {
        "temp" => 20,
        "humidity" => 65
      },
      "weather" => [
        {
          "main" => "Clear",
          "description" => "clear sky"
        }
      ],
      "name" => "London"
    }
    
    stub_request(:get, %r{api\.openweathermap\.org/data/2\.5/weather})
      .to_return(
        status: 200,
        body: mock_weather_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    assert_nothing_raised do
      FetchDataSourceJob.perform_now(@data_source.id)
    end
  end

  test "should handle data source not found" do
    non_existent_id = 99999
    
    # Should not raise an exception, just log the error
    assert_nothing_raised do
      FetchDataSourceJob.perform_now(non_existent_id)
    end
  end

  test "should handle fetch_data failure" do
    # Stub the weather API to return an error
    stub_request(:get, %r{api\.openweathermap\.org/data/2\.5/weather})
      .to_return(status: 500, body: "Internal Server Error")
    
    # The job should handle the error gracefully
    assert_nothing_raised do
      FetchDataSourceJob.perform_now(@data_source.id)
    end
  end

  test "should be queued on default queue" do
    assert_enqueued_with(job: FetchDataSourceJob, queue: "default") do
      FetchDataSourceJob.perform_later(@data_source.id)
    end
  end

  test "should call fetch_data on the data source" do
    mock_weather_response = {
      "main" => { "temp" => 20 },
      "weather" => [{ "main" => "Clear" }],
      "name" => "London"
    }
    
    stub_request(:get, %r{api\.openweathermap\.org/data/2\.5/weather})
      .to_return(
        status: 200,
        body: mock_weather_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    FetchDataSourceJob.perform_now(@data_source.id)
    
    # Check that data point was created
    assert @data_source.data_points.exists?
  end

  test "should handle network errors gracefully" do
    # Stub the weather API to simulate network error
    stub_request(:get, %r{api\.openweathermap\.org/data/2\.5/weather})
      .to_raise(SocketError.new("Network unreachable"))
    
    # The job should handle the error gracefully
    assert_nothing_raised do
      FetchDataSourceJob.perform_now(@data_source.id)
    end
  end

  test "should handle timeout errors gracefully" do
    # Stub the weather API to simulate timeout
    stub_request(:get, %r{api\.openweathermap\.org/data/2\.5/weather})
      .to_timeout
    
    # The job should handle the error gracefully
    assert_nothing_raised do
      FetchDataSourceJob.perform_now(@data_source.id)
    end
  end

  test "should work with different data source types" do
    # Mock all API responses
    stub_request(:get, %r{api\.openweathermap\.org/data/2\.5/weather})
      .to_return(
        status: 200,
        body: { "main" => { "temp" => 20 }, "weather" => [{ "main" => "Clear" }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    stub_request(:get, "https://www.alphavantage.co/query")
      .with(query: hash_including(apikey: "test_key"))
      .to_return(
        status: 200,
        body: { 
          "Global Quote" => { 
            "01. symbol" => "AAPL", 
            "05. price" => "150.00",
            "09. change" => "2.50",
            "10. change percent" => "1.69%",
            "06. volume" => "50000000",
            "08. previous close" => "147.50"
          } 
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    stub_request(:get, %r{newsapi\.org/v2})
      .to_return(
        status: 200,
        body: { 
          "status" => "ok", 
          "articles" => [
            {
              "title" => "Test News",
              "description" => "Test description",
              "url" => "https://example.com/news",
              "publishedAt" => "2024-01-15T10:00:00Z"
            }
          ] 
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    stub_request(:get, %r{ipapi\.co})
      .to_return(
        status: 200,
        body: { 
          "city" => "London", 
          "country" => "UK",
          "country_name" => "United Kingdom",
          "region" => "England",
          "latitude" => 51.5074,
          "longitude" => -0.1278
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    stub_request(:get, %r{api\.example\.com/custom})
      .to_return(
        status: 200,
        body: { "data" => "custom", "status" => "ok", "result" => { "value" => "test" } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    data_sources = []
    
    # Create different types of data sources with correct endpoints
    data_sources << DataSource.create!(
      name: "weather_job_test",
      source_type: "weather",
      api_endpoint: "https://api.openweathermap.org/data/2.5/weather",
      api_key: "test_key",
      user: @user,
      active: true
    )
    
    data_sources << DataSource.create!(
      name: "stock_job_test",
      source_type: "stock",
      api_endpoint: "https://www.alphavantage.co/query",
      api_key: "test_key",
      configuration: { "default_symbol" => "AAPL" },
      user: @user,
      active: true
    )
    
    data_sources << DataSource.create!(
      name: "news_job_test",
      source_type: "news",
      api_endpoint: "https://newsapi.org/v2/top-headlines",
      api_key: "test_key",
      user: @user,
      active: true
    )
    
    data_sources << DataSource.create!(
      name: "location_job_test",
      source_type: "location",
      api_endpoint: "https://ipapi.co/json",
      user: @user,
      active: true
    )
    
    data_sources << DataSource.create!(
      name: "custom_job_test",
      source_type: "custom",
      api_endpoint: "https://api.example.com/custom",
      api_key: "test_key",
      user: @user,
      active: true
    )
    
    data_sources.each do |ds|
      assert_nothing_raised do
        FetchDataSourceJob.perform_now(ds.id)
      end
    end
  end

  test "should handle inactive data sources" do
    @data_source.update!(active: false)
    
    mock_weather_response = {
      "main" => { "temp" => 20 },
      "weather" => [{ "main" => "Clear" }],
      "name" => "London"
    }
    
    stub_request(:get, %r{api\.openweathermap\.org/data/2\.5/weather})
      .to_return(
        status: 200,
        body: mock_weather_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    # Job should still run even for inactive data sources
    assert_nothing_raised do
      FetchDataSourceJob.perform_now(@data_source.id)
    end
  end

  test "should retry on retryable errors" do
    # Stub the weather API to simulate a temporary error
    stub_request(:get, %r{api\.openweathermap\.org/data/2\.5/weather})
      .to_return(status: 503, body: "Service Temporarily Unavailable")
    
    # The job should handle the error gracefully (Sidekiq will handle retries)
    assert_nothing_raised do
      FetchDataSourceJob.perform_now(@data_source.id)
    end
  end

  test "should preserve job arguments" do
    job = FetchDataSourceJob.new(@data_source.id)
    assert_equal [@data_source.id], job.arguments
  end

  test "should be serializable" do
    job = FetchDataSourceJob.new(@data_source.id)
    serialized = job.serialize
    
    assert_equal "FetchDataSourceJob", serialized["job_class"]
    assert_equal [@data_source.id], serialized["arguments"]
    assert_equal "default", serialized["queue_name"]
  end
end