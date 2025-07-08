require "test_helper"

class DataSourceIntegrationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = users(:one)
    sign_in @user
  end

  test "complete data source lifecycle with job processing" do
    # Create a weather data source
    weather_source = DataSource.create!(
      name: "integration_weather",
      source_type: "weather",
      api_endpoint: "https://api.openweathermap.org/data/2.5/weather",
      api_key: "test_integration_key",
      configuration: {
        "city" => "London",
        "units" => "metric",
        "cache_duration" => 60
      },
      user: @user,
      active: true
    )

    # Mock successful API response for weather service
    mock_weather_response = {
      "main" => {
        "temp" => 18.5,
        "feels_like" => 17.2,
        "humidity" => 72
      },
      "weather" => [
        {
          "main" => "Clouds",
          "description" => "overcast clouds"
        }
      ],
      "name" => "London"
    }

    # Mock the weather service response
    stub_request(:get, %r{api\.openweathermap\.org/data/2\.5/weather})
      .to_return(
        status: 200,
        body: mock_weather_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Test manual data fetch
    result = weather_source.fetch_data
    assert result.success?
    assert_equal 18.5, result.data["temperature"]
    assert_equal "overcast clouds", result.data["description"]

    # Verify data point was created
    data_point = weather_source.data_points.last
    assert_not_nil data_point
    assert_equal "weather_data", data_point.key
    assert_equal 18.5, data_point.value["temperature"]
    assert data_point.expires_at > Time.current

    # Test job processing
    assert_enqueued_with(job: FetchDataSourceJob, args: [weather_source.id]) do
      FetchDataSourceJob.perform_later(weather_source.id)
    end

    # Execute the job
    perform_enqueued_jobs do
      FetchDataSourceJob.perform_later(weather_source.id)
    end

    # Verify job updated the data
    weather_source.reload
    latest_data_point = weather_source.data_points.order(created_at: :desc).first
    assert_not_nil latest_data_point
    assert latest_data_point.fetched_at.present?
  end

  test "data source with expired data triggers refresh job" do
    # Create a stock data source with expired data
    stock_source = DataSource.create!(
      name: "integration_stock",
      source_type: "stock",
      api_endpoint: "https://www.alphavantage.co/query",
      api_key: "test_stock_key",
      configuration: {
        "default_symbol" => "AAPL",
        "cache_duration" => 30
      },
      user: @user,
      active: true
    )

    # Create expired data point
    expired_data_point = stock_source.data_points.create!(
      key: "stock_data",
      value: {
        "symbol" => "AAPL",
        "price" => 150.00,
        "change" => 2.50
      },
      fetched_at: 2.hours.ago,
      expires_at: 1.hour.ago  # Expired
    )

    # Verify data needs refresh
    assert stock_source.needs_refresh?

    # Test refresh all job
    mock_stock_response = {
      "Global Quote" => {
        "01. symbol" => "AAPL",
        "05. price" => "152.75",
        "09. change" => "5.25",
        "10. change percent" => "3.56%",
        "06. volume" => "1234567",
        "08. previous close" => "147.50"
      }
    }

    stub_request(:get, "https://www.alphavantage.co/query")
      .with(
        query: {
          function: "GLOBAL_QUOTE",
          symbol: "AAPL",
          apikey: "test_stock_key"
        }
      )
      .to_return(
        status: 200,
        body: mock_stock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Execute refresh job
    perform_enqueued_jobs do
      RefreshAllDataSourcesJob.perform_now
    end

    # Verify new data was fetched
    stock_source.reload
    latest_data_point = stock_source.data_points.order(created_at: :desc).first
    assert latest_data_point.id != expired_data_point.id
    assert_equal 152.75, latest_data_point.value[:price]
    assert latest_data_point.expires_at > Time.current
  end

  test "multiple data sources with different refresh requirements" do
    # Create multiple data sources with different states
    fresh_source = DataSource.create!(
      name: "fresh_news",
      source_type: "news",
      api_endpoint: "https://newsapi.org/v2/top-headlines",
      api_key: "test_news_key",
      user: @user,
      active: true
    )

    stale_source = DataSource.create!(
      name: "stale_location",
      source_type: "location",
      api_endpoint: "https://ipapi.co/json",
      user: @user,
      active: true
    )

    inactive_source = DataSource.create!(
      name: "inactive_weather",
      source_type: "weather",
      api_endpoint: "https://api.openweathermap.org/data/2.5/weather",
      api_key: "test_key",
      user: @user,
      active: false
    )

    # Add fresh data to first source
    fresh_source.data_points.create!(
      key: "news_data",
      value: { "articles" => [] },
      fetched_at: 10.minutes.ago,
      expires_at: 50.minutes.from_now  # Still valid
    )

    # Add stale data to second source
    stale_source.data_points.create!(
      key: "location_data",
      value: { "city" => "London" },
      fetched_at: 2.hours.ago,
      expires_at: 1.hour.ago  # Expired
    )

    # Mock API responses
    stub_request(:get, %r{ipapi\.co/json})
      .to_return(
        status: 200,
        body: { "city" => "London", "country" => "UK" }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Track which jobs are enqueued
    assert_enqueued_jobs 1, only: FetchDataSourceJob do
      RefreshAllDataSourcesJob.perform_now
    end

    # Only the stale source should have been refreshed
    # (fresh source doesn't need refresh, inactive source is skipped)
  end

  test "data source API error handling in job processing" do
    error_source = DataSource.create!(
      name: "error_prone_source",
      source_type: "custom",
      api_endpoint: "https://api.error.com/data",
      api_key: "test_error_key",
      user: @user,
      active: true
    )

    # Mock API error response
    stub_request(:get, %r{api\.error\.com/data})
      .to_return(status: 500, body: "Internal Server Error")

    # Execute job and expect it to handle error gracefully
    assert_raises StandardError do
      perform_enqueued_jobs do
        FetchDataSourceJob.perform_now(error_source.id)
      end
    end

    # Data source should still exist and be active
    error_source.reload
    assert error_source.active?
  end

  test "data source network timeout handling" do
    timeout_source = DataSource.create!(
      name: "timeout_source",
      source_type: "weather",
      api_endpoint: "https://api.slow.com/weather",
      api_key: "test_timeout_key",
      user: @user,
      active: true
    )

    # Mock network timeout - match the actual API being called
    stub_request(:get, %r{api\.openweathermap\.org/data/2\.5/weather})
      .with(query: hash_including(appid: "test_timeout_key"))
      .to_timeout

    # Execute job and expect timeout to be handled
    assert_raises Timeout::Error do
      perform_enqueued_jobs do
        FetchDataSourceJob.perform_now(timeout_source.id)
      end
    end

    # Data source should remain active
    timeout_source.reload
    assert timeout_source.active?
  end

  test "data source with complex configuration and custom parameters" do
    complex_source = DataSource.create!(
      name: "complex_api_source",
      source_type: "custom",
      api_endpoint: "https://api.complex.com/data",
      api_key: "complex_api_key",
      configuration: {
        "region" => "us-east",
        "format" => "json",
        "include_metadata" => true,
        "filters" => {
          "category" => "technology",
          "date_range" => "last_7_days"
        },
        "pagination" => {
          "page_size" => 50,
          "max_pages" => 3
        }
      },
      user: @user,
      active: true
    )

    # Mock complex API response
    mock_complex_response = {
      "data" => [
        {
          "id" => 1,
          "title" => "Complex Data Item 1",
          "category" => "technology",
          "timestamp" => "2024-01-15T10:00:00Z"
        }
      ],
      "metadata" => {
        "total_count" => 1,
        "page" => 1,
        "region" => "us-east"
      }
    }

    stub_request(:get, %r{api\.complex\.com/data})
      .with(query: hash_including(
        region: "us-east",
        format: "json",
        category: "technology",
        custom_param: "test_value"
      ))
      .to_return(
        status: 200,
        body: mock_complex_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Test data fetch with complex configuration
    result = complex_source.fetch_data({
      "category" => "technology",
      "custom_param" => "test_value"
    })

    assert result.success?
    assert_equal 1, result.data["data"].length
    assert_equal "Complex Data Item 1", result.data["data"][0]["title"]
    assert_equal "us-east", result.metadata["region"]
  end

  test "concurrent data source job processing" do
    # Create multiple data sources that need refresh
    sources = []
    3.times do |i|
      source = DataSource.create!(
        name: "concurrent_source_#{i}",
        source_type: "weather",
        api_endpoint: "https://api.concurrent#{i}.com/data",
        api_key: "test_key_#{i}",
        user: @user,
        active: true
      )
      
      # Add expired data to each
      source.data_points.create!(
        key: "data_#{i}",
        value: { "value" => i },
        fetched_at: 2.hours.ago,
        expires_at: 1.hour.ago
      )
      
      sources << source
    end

    # Mock API responses for all sources
    sources.each_with_index do |source, i|
      stub_request(:get, %r{api\.concurrent#{i}\.com/data})
        .to_return(
          status: 200,
          body: { "updated_value" => i * 10 }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    # Execute refresh job which should process all sources
    assert_enqueued_jobs 3, only: FetchDataSourceJob do
      RefreshAllDataSourcesJob.perform_now
    end

    # Execute all enqueued jobs
    perform_enqueued_jobs

    # Verify all sources were updated
    sources.each_with_index do |source, i|
      source.reload
      latest_data = source.data_points.order(created_at: :desc).first
      assert_equal i * 10, latest_data.value["updated_value"]
    end
  end

  test "data source job queue management" do
    # Test that jobs are enqueued on correct queues
    high_priority_source = DataSource.create!(
      name: "high_priority",
      source_type: "stock",
      api_endpoint: "https://api.stocks.com/data",
      api_key: "test_key",
      user: @user,
      active: true
    )

    # FetchDataSourceJob should be on default queue
    assert_enqueued_with(job: FetchDataSourceJob, queue: "default") do
      FetchDataSourceJob.perform_later(high_priority_source.id)
    end

    # RefreshAllDataSourcesJob should be on low priority queue
    assert_enqueued_with(job: RefreshAllDataSourcesJob, queue: "low") do
      RefreshAllDataSourcesJob.perform_later
    end
  end

  test "data source integration with PDF template generation" do
    # Create data source with location data
    location_source = DataSource.create!(
      name: "pdf_location_data",
      source_type: "location",
      api_endpoint: "https://ipapi.co/json",
      user: @user,
      active: true
    )

    # Add location data
    location_data = location_source.data_points.create!(
      key: "current_location",
      value: {
        "city" => "New York",
        "region" => "New York",
        "country" => "US",
        "latitude" => 40.7128,
        "longitude" => -74.0060,
        "timezone" => "America/New_York"
      },
      fetched_at: Time.current,
      expires_at: 24.hours.from_now
    )

    # Create PDF template that uses location data
    location_template = PdfTemplate.create!(
      name: "Location Report",
      description: "Report with location data",
      template_content: <<~'HTML',
        <div class="location-report">
          <h1>Location Report</h1>
          <div class="location-details">
            <p><strong>City:</strong> {{city}}</p>
            <p><strong>Region:</strong> {{region}}</p>
            <p><strong>Country:</strong> {{country}}</p>
            <p><strong>Coordinates:</strong> {{latitude}}, {{longitude}}</p>
            <p><strong>Timezone:</strong> {{timezone}}</p>
          </div>
          <div class="report-metadata">
            <p><strong>Generated:</strong> {{generation_date}}</p>
            <p><strong>Data Source:</strong> {{data_source_name}}</p>
          </div>
        </div>
      HTML
      user: @user,
      active: true
    )

    # Generate PDF with location data
    mock_pdf_content = "LOCATION_REPORT_PDF"
    Grover.any_instance.stub(:to_pdf, mock_pdf_content) do
      post pdf_template_processed_pdfs_path(location_template), params: {
        processed_pdf: {
          metadata: {
            "data_source_id" => location_source.id,
            "data_point_id" => location_data.id
          }
        },
        variables: {
          "city" => location_data.value["city"],
          "region" => location_data.value["region"],
          "country" => location_data.value["country"],
          "latitude" => location_data.value["latitude"].to_s,
          "longitude" => location_data.value["longitude"].to_s,
          "timezone" => location_data.value["timezone"],
          "generation_date" => Time.current.strftime("%Y-%m-%d %H:%M:%S"),
          "data_source_name" => location_source.name
        }
      }
    end

    assert_response :redirect
    follow_redirect!
    assert_response :success

    # Verify PDF was generated with location data
    generated_pdf = ProcessedPdf.last
    assert_includes generated_pdf.original_html, "New York"
    assert_includes generated_pdf.original_html, "America/New_York"
    assert_equal location_source.id.to_s, generated_pdf.metadata["data_source_id"]
    assert_equal location_data.id.to_s, generated_pdf.metadata["data_point_id"]
  end

  test "scheduled data source refresh simulation" do
    # Create data sources that would be refreshed on a schedule
    scheduled_sources = []
    
    # Daily refresh source
    daily_source = DataSource.create!(
      name: "daily_weather",
      source_type: "weather",
      api_endpoint: "https://api.weather.com/daily",
      api_key: "daily_key",
      configuration: { "cache_duration" => 1440 }, # 24 hours
      user: @user,
      active: true
    )
    
    # Hourly refresh source
    hourly_source = DataSource.create!(
      name: "hourly_stock",
      source_type: "stock",
      api_endpoint: "https://api.stocks.com/hourly",
      api_key: "hourly_key",
      configuration: { "cache_duration" => 60 }, # 1 hour
      user: @user,
      active: true
    )

    scheduled_sources = [daily_source, hourly_source]

    # Add data with different expiration times
    daily_source.data_points.create!(
      key: "daily_data",
      value: { "temp" => 20 },
      fetched_at: 25.hours.ago,  # Expired (daily)
      expires_at: 1.hour.ago
    )

    hourly_source.data_points.create!(
      key: "hourly_data",
      value: { "price" => 100 },
      fetched_at: 2.hours.ago,   # Expired (hourly)
      expires_at: 1.hour.ago
    )

    # Mock API responses
    stub_request(:get, %r{api\.weather\.com/daily})
      .to_return(
        status: 200,
        body: { "temp" => 22 }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:get, %r{api\.stocks\.com/hourly})
      .to_return(
        status: 200,
        body: { "price" => 105 }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Simulate scheduled refresh (like a cron job would do)
    assert_enqueued_jobs 2, only: FetchDataSourceJob do
      RefreshAllDataSourcesJob.perform_now
    end

    # Execute the jobs
    perform_enqueued_jobs

    # Verify both sources were refreshed
    daily_source.reload
    hourly_source.reload

    daily_latest = daily_source.data_points.order(created_at: :desc).first
    hourly_latest = hourly_source.data_points.order(created_at: :desc).first

    assert_equal 22, daily_latest.value["temp"]
    assert_equal 105, hourly_latest.value["price"]
    assert daily_latest.expires_at > Time.current
    assert hourly_latest.expires_at > Time.current
  end
end