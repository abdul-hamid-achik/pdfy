require "test_helper"

class LocationServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @data_source = DataSource.create!(
      name: "location_test",
      source_type: "location",
      api_endpoint: "https://ipapi.co/json",
      configuration: {
        "cache_duration" => 1440
      },
      user: @user,
      active: true
    )
    @service = LocationService.new(@data_source)
  end

  test "should make successful API request" do
    mock_response = {
      "ip" => "8.8.8.8",
      "city" => "Mountain View",
      "region" => "California",
      "country" => "US",
      "country_name" => "United States",
      "postal" => "94035",
      "latitude" => 37.386,
      "longitude" => -122.0838,
      "timezone" => "America/Los_Angeles",
      "utc_offset" => "-0800"
    }

    stub_request(:get, "https://ipapi.co/json")
      .with(headers: { 'User-Agent' => 'PDFy/1.0' })
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert_equal "Mountain View", result.data["city"]
    assert_equal "United States", result.data["country"]
    assert_equal "America/Los_Angeles", result.data["timezone"]
    assert_equal 37.386, result.data["latitude"]
    assert_equal -122.0838, result.data["longitude"]
  end

  test "should handle specific IP lookup" do
    mock_response = {
      "ip" => "1.1.1.1",
      "city" => "Sydney",
      "region" => "New South Wales",
      "country" => "AU",
      "country_name" => "Australia",
      "postal" => "2000",
      "latitude" => -33.8688,
      "longitude" => 151.2093,
      "timezone" => "Australia/Sydney",
      "utc_offset" => "+1100"
    }

    stub_request(:get, "https://ipapi.co/1.1.1.1/")
      .with(headers: { 'User-Agent' => 'PDFy/1.0' })
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ "ip" => "1.1.1.1" })

    assert result.success?
    assert_equal "Sydney", result.data["city"]
    assert_equal "Australia", result.data["country"]
    assert_equal "Australia/Sydney", result.data["timezone"]
  end

  test "should handle API error response" do
    error_response = {
      "error" => true,
      "reason" => "RateLimited"
    }

    stub_request(:get, "https://ipapi.co/json")
      .to_return(
        status: 429,
        body: error_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error, "RateLimited"
  end

  test "should handle private IP addresses" do
    error_response = {
      "error" => true,
      "reason" => "Private IP address not supported"
    }

    stub_request(:get, "https://ipapi.co/192.168.1.1/json")
      .to_return(
        status: 400,
        body: error_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ "ip" => "192.168.1.1" })

    assert_not result.success?
    assert_includes result.error, "Private IP"
  end

  test "should include metadata in response" do
    mock_response = {
      "ip" => "8.8.8.8",
      "city" => "Mountain View",
      "region" => "California",
      "country" => "US",
      "country_name" => "United States",
      "postal" => "94035",
      "latitude" => 37.386,
      "longitude" => -122.0838,
      "timezone" => "America/Los_Angeles"
    }

    stub_request(:get, "https://ipapi.co/json")
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert result.metadata.present?
    assert_equal "ipapi", result.metadata["source"]
    assert result.metadata["timestamp"].present?
    assert_equal "8.8.8.8", result.metadata["ip_address"]
  end

  test "should handle missing location data" do
    incomplete_response = {
      "ip" => "8.8.8.8",
      "city" => "",
      "region" => "",
      "country" => "",
      "latitude" => nil,
      "longitude" => nil
    }

    stub_request(:get, "https://ipapi.co/json")
      .to_return(
        status: 200,
        body: incomplete_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error, "location data"
  end

  test "should handle invalid IP format" do
    error_response = {
      "error" => true,
      "reason" => "Invalid IP address format"
    }

    stub_request(:get, "https://ipapi.co/invalid_ip/")
      .to_return(
        status: 400,
        body: error_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ "ip" => "invalid_ip" })

    assert_not result.success?
    assert_includes result.error, "Invalid IP"
  end

  test "should handle network errors" do
    stub_request(:get, "https://ipapi.co/json")
      .to_raise(SocketError.new("Network unreachable"))

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error, "Network unreachable"
  end

  test "should handle timeout errors" do
    stub_request(:get, "https://ipapi.co/json/")
      .to_timeout

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error.downcase, "timeout"
  end

  test "should handle invalid JSON response" do
    stub_request(:get, "https://ipapi.co/json/")
      .to_return(
        status: 200,
        body: "Invalid JSON {",
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error.downcase, "json"
  end

  test "should handle different location formats" do
    mock_response = {
      "ip" => "203.0.113.1",
      "city" => "London",
      "region" => "England",
      "country" => "GB",
      "country_name" => "United Kingdom",
      "postal" => "EC1A",
      "latitude" => 51.5074,
      "longitude" => -0.1278,
      "timezone" => "Europe/London",
      "utc_offset" => "+0000",
      "country_calling_code" => "+44",
      "currency" => "GBP",
      "languages" => "en"
    }

    stub_request(:get, "https://ipapi.co/json")
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert_equal "London", result.data["city"]
    assert_equal "United Kingdom", result.data["country"]
    assert_equal "Europe/London", result.data["timezone"]
    assert_equal 51.5074, result.data["latitude"]
    assert_equal -0.1278, result.data["longitude"]
  end

  test "should work with custom endpoint" do
    # First stub the default ipapi endpoint that might be called
    stub_request(:get, "https://ipapi.co/json/")
      .to_return(
        status: 200,
        body: { "ip" => "127.0.0.1", "city" => "Local" }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    @data_source.update!(api_endpoint: "https://custom-geo-api.com/locate")
    
    mock_response = {
      "ip" => "8.8.8.8",
      "city" => "Custom City",
      "country" => "Custom Country",
      "latitude" => 40.7128,
      "longitude" => -74.0060,
      "timezone" => "America/New_York"
    }

    stub_request(:get, "https://custom-geo-api.com/locate")
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert_equal "Custom City", result.data["city"]
    assert_equal "Custom Country", result.data["country"]
  end

  test "should handle IPv6 addresses" do
    mock_response = {
      "ip" => "2001:4860:4860::8888",
      "city" => "Mountain View",
      "region" => "California",
      "country" => "US",
      "country_name" => "United States",
      "latitude" => 37.386,
      "longitude" => -122.0838,
      "timezone" => "America/Los_Angeles"
    }

    stub_request(:get, "https://ipapi.co/2001:4860:4860::8888/json")
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ "ip" => "2001:4860:4860::8888" })

    assert result.success?
    assert_equal "Mountain View", result.data["city"]
    assert_equal "2001:4860:4860::8888", result.metadata["ip_address"]
  end

  test "should normalize empty strings to nil" do
    mock_response = {
      "ip" => "8.8.8.8",
      "city" => "",  # Empty string
      "region" => "California",
      "country" => "US",
      "country_name" => "United States",
      "postal" => "",  # Empty string
      "latitude" => 37.386,
      "longitude" => -122.0838,
      "timezone" => "America/Los_Angeles"
    }

    stub_request(:get, "https://ipapi.co/json")
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert_not result.success?  # Should fail due to empty city
    assert_includes result.error, "location data"
  end
end