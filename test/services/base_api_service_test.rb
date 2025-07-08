require "test_helper"

class BaseApiServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @data_source = DataSource.create!(
      name: "test_api",
      source_type: "custom",
      api_endpoint: "https://api.example.com/data",
      api_key: "test_key",
      user: @user,
      active: true
    )
    @service = BaseApiService.new(@data_source)
  end

  test "should initialize with data_source" do
    assert_equal @data_source, @service.data_source
  end

  test "should call make_request when fetching" do
    mock_response = { "status" => "success", "data" => "test" }
    
    # Mock the make_request method
    @service.define_singleton_method(:make_request) do |params|
      OpenStruct.new(
        success?: true,
        data: mock_response,
        metadata: { "timestamp" => Time.current.iso8601 }
      )
    end
    
    result = @service.fetch({})
    
    assert result.success?
    assert_equal mock_response, result.data
    assert result.metadata.key?("timestamp")
  end

  test "should handle make_request returning failure" do
    # Mock the make_request method to return failure
    @service.define_singleton_method(:make_request) do |params|
      OpenStruct.new(
        success?: false,
        data: nil,
        error: "API request failed",
        metadata: { "error_type" => "network" }
      )
    end
    
    result = @service.fetch({})
    
    assert_not result.success?
    assert_nil result.data
    assert_equal "API request failed", result.error
  end

  test "should handle exceptions in make_request" do
    # Mock the make_request method to raise an exception
    @service.define_singleton_method(:make_request) do |params|
      raise StandardError, "Network timeout"
    end
    
    result = @service.fetch({})
    
    assert_not result.success?
    assert_nil result.data
    assert_includes result.error, "Network timeout"
  end

  test "should provide access to data_source properties" do
    assert_equal "https://api.example.com/data", @service.data_source.api_endpoint
    assert_equal "test_key", @service.data_source.api_key
    assert_equal "custom", @service.data_source.source_type
  end

  test "should handle different parameter types" do
    test_params = {
      "string" => "value",
      "number" => 42,
      "boolean" => true,
      "array" => [1, 2, 3],
      "hash" => { "nested" => "value" }
    }
    
    received_params = nil
    
    @service.define_singleton_method(:make_request) do |params|
      received_params = params
      OpenStruct.new(success?: true, data: {}, metadata: {})
    end
    
    @service.fetch(test_params)
    
    assert_equal test_params, received_params
  end

  test "should maintain consistent result structure" do
    @service.define_singleton_method(:make_request) do |params|
      OpenStruct.new(
        success?: true,
        data: { "result" => "success" },
        metadata: { "processed_at" => Time.current }
      )
    end
    
    result = @service.fetch({})
    
    # Check that result responds to expected methods
    assert_respond_to result, :success?
    assert_respond_to result, :data
    assert_respond_to result, :metadata
    
    # Check result structure
    assert result.success?
    assert_equal({ "result" => "success" }, result.data)
    assert result.metadata.key?("processed_at")
  end

  test "should allow subclasses to override make_request" do
    # Create a custom service class
    custom_service_class = Class.new(BaseApiService) do
      def make_request(params)
        OpenStruct.new(
          success?: true,
          data: { "custom" => "response", "params" => params },
          metadata: { "service_type" => "custom" }
        )
      end
    end
    
    custom_service = custom_service_class.new(@data_source)
    result = custom_service.fetch({ "test" => "param" })
    
    assert result.success?
    assert_equal "response", result.data["custom"]
    assert_equal({ "test" => "param" }, result.data["params"])
    assert_equal "custom", result.metadata["service_type"]
  end

  test "should handle empty parameters" do
    @service.define_singleton_method(:make_request) do |params|
      OpenStruct.new(
        success?: true,
        data: { "params_received" => params },
        metadata: {}
      )
    end
    
    result = @service.fetch({})
    
    assert result.success?
    assert_equal({}, result.data["params_received"])
  end

  test "should handle nil parameters" do
    @service.define_singleton_method(:make_request) do |params|
      OpenStruct.new(
        success?: true,
        data: { "params_received" => params },
        metadata: {}
      )
    end
    
    result = @service.fetch(nil)
    
    assert result.success?
    assert_nil result.data["params_received"]
  end

  test "should provide default error handling" do
    # Don't define parse_response, make_request returns success
    @service.define_singleton_method(:make_request) do |params|
      OpenStruct.new(code: 200, parsed_response: { "data" => "test" })
    end
    
    result = @service.fetch({})
    
    assert_not result.success?
    assert_nil result.data
    assert_includes result.error, "Subclasses must implement parse_response"
  end

  test "should handle timeout errors" do
    @service.define_singleton_method(:make_request) do |params|
      raise Timeout::Error, "Request timed out"
    end
    
    result = @service.fetch({})
    
    assert_not result.success?
    assert_includes result.error, "Request timed out"
  end

  test "should handle network errors" do
    @service.define_singleton_method(:make_request) do |params|
      raise SocketError, "Network unreachable"
    end
    
    result = @service.fetch({})
    
    assert_not result.success?
    assert_includes result.error, "Network unreachable"
  end

  test "should allow metadata to be optional" do
    @service.define_singleton_method(:make_request) do |params|
      OpenStruct.new(
        success?: true,
        data: { "result" => "success" }
        # No metadata provided
      )
    end
    
    result = @service.fetch({})
    
    assert result.success?
    assert_equal({ "result" => "success" }, result.data)
    # Should handle missing metadata gracefully
    assert_respond_to result, :metadata
  end

  test "should preserve original exception information" do
    original_error = StandardError.new("Original error message")
    original_error.set_backtrace(["line 1", "line 2", "line 3"])
    
    @service.define_singleton_method(:make_request) do |params|
      raise original_error
    end
    
    result = @service.fetch({})
    
    assert_not result.success?
    assert_includes result.error, "Original error message"
  end
end