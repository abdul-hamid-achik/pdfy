require "test_helper"

class RefreshAllDataSourcesJobTest < ActiveJob::TestCase
  def setup
    @user = users(:one)
    @active_data_source = DataSource.create!(
      name: "active_weather",
      source_type: "weather",
      api_endpoint: "https://api.openweathermap.org/data/2.5/weather",
      api_key: "test_key",
      user: @user,
      active: true
    )
    
    @inactive_data_source = DataSource.create!(
      name: "inactive_stock",
      source_type: "stock",
      api_endpoint: "https://api.example.com/stock",
      api_key: "test_key",
      user: @user,
      active: false
    )
  end

  test "should perform job successfully" do
    assert_nothing_raised do
      RefreshAllDataSourcesJob.perform_now
    end
  end

  test "should only process active data sources" do
    # Mock needs_refresh? to return true for all sources
    DataSource.any_instance.stubs(:needs_refresh?).returns(true)
    
    assert_enqueued_jobs 1, only: FetchDataSourceJob do
      RefreshAllDataSourcesJob.perform_now
    end
  end

  test "should not enqueue jobs for sources that don't need refresh" do
    # Create fresh data points for all active sources
    @active_data_source.data_points.create!(
      key: "fresh_data",
      value: { "temp" => 20 },
      fetched_at: 5.minutes.ago,
      expires_at: 55.minutes.from_now
    )
    
    # Mock needs_refresh? to return false for all sources
    DataSource.any_instance.stubs(:needs_refresh?).returns(false)
    
    assert_no_enqueued_jobs only: FetchDataSourceJob do
      RefreshAllDataSourcesJob.perform_now
    end
  end

  test "should enqueue jobs for sources that need refresh" do
    # Create expired data point for active source
    @active_data_source.data_points.create!(
      key: "weather_data",
      value: { "temp" => 20 },
      fetched_at: 2.hours.ago,
      expires_at: 1.hour.ago  # Expired
    )
    
    assert_enqueued_with(job: FetchDataSourceJob, args: [@active_data_source.id]) do
      RefreshAllDataSourcesJob.perform_now
    end
  end

  test "should be queued on low priority queue" do
    assert_enqueued_with(job: RefreshAllDataSourcesJob, queue: "low") do
      RefreshAllDataSourcesJob.perform_later
    end
  end

  test "should handle multiple data sources needing refresh" do
    # Create multiple active data sources
    sources = []
    3.times do |i|
      source = DataSource.create!(
        name: "source_#{i}",
        source_type: "weather",
        api_endpoint: "https://api.example.com/#{i}",
        api_key: "test_key",
        user: @user,
        active: true
      )
      
      # Create expired data for each source
      source.data_points.create!(
        key: "data_#{i}",
        value: { "value" => i },
        fetched_at: 2.hours.ago,
        expires_at: 1.hour.ago
      )
      
      sources << source
    end
    
    # Should enqueue jobs for all active sources plus the original one
    # Original has no data points, so it needs refresh too
    assert_enqueued_jobs 4, only: FetchDataSourceJob do
      RefreshAllDataSourcesJob.perform_now
    end
  end

  test "should handle data sources with no data points" do
    # Data source with no data points should need refresh
    empty_source = DataSource.create!(
      name: "empty_source",
      source_type: "news",
      api_endpoint: "https://api.example.com/news",
      api_key: "test_key",
      user: @user,
      active: true
    )
    
    # Should enqueue jobs for both active sources (one with expired data, one with no data)
    assert_enqueued_jobs 2, only: FetchDataSourceJob do
      RefreshAllDataSourcesJob.perform_now
    end
  end

  test "should handle mixed scenarios" do
    # Create various data sources with different states
    
    # Source with fresh data (shouldn't need refresh)
    fresh_source = DataSource.create!(
      name: "fresh_source",
      source_type: "location",
      api_endpoint: "https://api.example.com/location",
      user: @user,
      active: true
    )
    fresh_source.data_points.create!(
      key: "location_data",
      value: { "city" => "London" },
      fetched_at: 10.minutes.ago,
      expires_at: 50.minutes.from_now  # Still valid
    )
    
    # Source with expired data (should need refresh)
    expired_source = DataSource.create!(
      name: "expired_source",
      source_type: "stock",
      api_endpoint: "https://api.example.com/stock",
      user: @user,
      active: true
    )
    expired_source.data_points.create!(
      key: "stock_data",
      value: { "price" => 100 },
      fetched_at: 2.hours.ago,
      expires_at: 1.hour.ago  # Expired
    )
    
    # Inactive source (shouldn't be processed)
    # @inactive_data_source already created in setup
    
    # Should only enqueue jobs for sources that need refresh and are active
    # That's: @active_data_source (no data), expired_source (expired data)
    assert_enqueued_jobs 2, only: FetchDataSourceJob do
      RefreshAllDataSourcesJob.perform_now
    end
  end

  test "should handle errors gracefully" do
    # Mock DataSource.active to raise an error
    DataSource.stubs(:active).raises(StandardError, "Database error")
    
    assert_raises StandardError do
      RefreshAllDataSourcesJob.perform_now
    end
  end

  test "should handle large numbers of data sources efficiently" do
    # Create many data sources
    20.times do |i|
      DataSource.create!(
        name: "bulk_source_#{i}",
        source_type: "weather",
        api_endpoint: "https://api.example.com/#{i}",
        api_key: "test_key",
        user: @user,
        active: true
      )
    end
    
    # Mock all sources to need refresh
    DataSource.any_instance.stubs(:needs_refresh?).returns(true)
    
    # Should enqueue jobs for all active sources (20 + 1 original)
    assert_enqueued_jobs 21, only: FetchDataSourceJob do
      RefreshAllDataSourcesJob.perform_now
    end
  end

  test "should work with find_each for memory efficiency" do
    # This test ensures we're using find_each which is memory efficient
    # We can't directly test find_each usage, but we can test behavior
    
    find_each_called = false
    
    # Create a custom expectation for find_each
    mock_scope = DataSource.active
    mock_scope.expects(:find_each).yields(@active_data_source)
    
    DataSource.stubs(:active).returns(mock_scope)
    
    RefreshAllDataSourcesJob.perform_now
  end

  test "should preserve job configuration" do
    job = RefreshAllDataSourcesJob.new
    serialized = job.serialize
    
    assert_equal "RefreshAllDataSourcesJob", serialized["job_class"]
    assert_equal [], serialized["arguments"]
    assert_equal "low", serialized["queue_name"]
  end

  test "should handle empty data source collection" do
    # Remove all data sources
    DataSource.destroy_all
    
    assert_no_enqueued_jobs only: FetchDataSourceJob do
      RefreshAllDataSourcesJob.perform_now
    end
  end
end