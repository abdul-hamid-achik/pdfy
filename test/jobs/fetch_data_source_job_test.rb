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
    # Mock fetch_data to raise an exception
    @data_source.stub(:fetch_data, -> { raise StandardError, "API error" }) do
      assert_raises StandardError do
        FetchDataSourceJob.perform_now(@data_source.id)
      end
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
    # Mock fetch_data to raise a network error
    @data_source.stub(:fetch_data, -> { raise SocketError, "Network unreachable" }) do
      assert_raises SocketError do
        FetchDataSourceJob.perform_now(@data_source.id)
      end
    end
  end

  test "should handle timeout errors gracefully" do
    # Mock fetch_data to raise a timeout error
    @data_source.stub(:fetch_data, -> { raise Timeout::Error, "Request timeout" }) do
      assert_raises Timeout::Error do
        FetchDataSourceJob.perform_now(@data_source.id)
      end
    end
  end

  test "should work with different data source types" do
    data_sources = []
    
    # Create different types of data sources
    %w[weather stock news location custom].each_with_index do |type, index|
      ds = DataSource.create!(
        name: "#{type}_job_test_#{index}",
        source_type: type,
        api_endpoint: "https://api.example.com/#{type}",
        api_key: "test_key",
        user: @user,
        active: true
      )
      data_sources << ds
    end
    
    data_sources.each do |ds|
      # Mock each data source's fetch_data method
      ds.define_singleton_method(:fetch_data) do
        OpenStruct.new(
          success?: true,
          data: { "type" => ds.source_type },
          metadata: { "fetched_at" => Time.current }
        )
      end
      
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
    retry_count = 0
    
    @data_source.define_singleton_method(:fetch_data) do
      retry_count += 1
      if retry_count < 3
        raise StandardError, "Temporary error"
      else
        OpenStruct.new(success?: true, data: {}, metadata: {})
      end
    end
    
    # This tests that the job can be retried (Sidekiq will handle retries)
    assert_raises StandardError do
      FetchDataSourceJob.perform_now(@data_source.id)
    end
    
    assert_equal 1, retry_count
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