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

    stub_request(:get, "https://ipapi.co/json/")
      .with(headers: { 'User-Agent' => 'PDFy/1.0' })
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert_equal "Mountain View", result.data[:city]
    assert_equal "United States", result.data[:country]
    assert_equal "America/Los_Angeles", result.data[:timezone]
    assert_equal 37.386, result.data[:latitude]
    assert_equal -122.0838, result.data[:longitude]
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
    assert_equal "Sydney", result.data[:city]
    assert_equal "Australia", result.data[:country]
    assert_equal "Australia/Sydney", result.data[:timezone]
  end

  test "should handle API error response" do
    error_response = {
      "error" => true,
      "reason" => "RateLimited"
    }

    stub_request(:get, "https://ipapi.co/json/")
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
      "reason" => "Reserved IP Address"
    }

    stub_request(:get, "https://ipapi.co/192.168.1.1/")
      .with(headers: { 'User-Agent' => 'PDFy/1.0' })
      .to_return(
        status: 200,
        body: error_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ "ip" => "192.168.1.1" })

    assert_not result.success?
    assert_includes result.error, "Reserved IP Address"
  end

  test "should handle missing location data" do
    partial_response = {
      "ip" => "8.8.8.8",
      "country" => "US",
      "country_name" => "United States"
      # Missing city, region, coordinates, etc.
    }

    stub_request(:get, "https://ipapi.co/json/")
      .with(headers: { 'User-Agent' => 'PDFy/1.0' })
      .to_return(
        status: 200,
        body: partial_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert_equal "United States", result.data[:country]
    assert_nil result.data[:city]
    assert_nil result.data[:latitude]
    assert_nil result.data[:longitude]
  end

  test "should normalize empty strings to nil" do
    mock_response = {
      "ip" => "8.8.8.8",
      "city" => "",
      "region" => "California",
      "country" => "US",
      "country_name" => "United States",
      "postal" => ""
    }

    stub_request(:get, "https://ipapi.co/json/")
      .with(headers: { 'User-Agent' => 'PDFy/1.0' })
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    # Empty strings should be preserved as is
    assert_equal "", result.data[:city]
    assert_equal "", result.data[:postal]
  end

  test "should handle invalid IP format" do
    stub_request(:get, "https://ipapi.co/invalid_ip/")
      .with(headers: { 'User-Agent' => 'PDFy/1.0' })
      .to_return(
        status: 404,
        body: "Not Found",
        headers: { 'Content-Type' => 'text/plain' }
      )

    result = @service.fetch({ ip: "invalid_ip" })

    assert_not result.success?
    assert_includes result.error, "404"
  end

  test "should handle network errors" do
    stub_request(:get, "https://ipapi.co/json/")
      .with(headers: { 'User-Agent' => 'PDFy/1.0' })
      .to_raise(Net::OpenTimeout)

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error, "execution expired"
  end

  test "should handle timeout errors" do
    stub_request(:get, "https://ipapi.co/json/")
      .with(headers: { 'User-Agent' => 'PDFy/1.0' })
      .to_timeout

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error.downcase, "timeout"
  end

  test "should handle invalid JSON response" do
    stub_request(:get, "https://ipapi.co/json/")
      .with(headers: { 'User-Agent' => 'PDFy/1.0' })
      .to_return(
        status: 200,
        body: "Invalid JSON {",
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error.downcase, "json"
  end

  test "should include all location fields" do
    mock_response = {
      "ip" => "8.8.8.8",
      "city" => "London",
      "region" => "England",
      "region_code" => "ENG",
      "country" => "GB",
      "country_name" => "United Kingdom",
      "country_code" => "GB",
      "country_capital" => "London",
      "country_area" => 242900,
      "country_population" => 66040229,
      "continent_code" => "EU",
      "latitude" => 51.5074,
      "longitude" => -0.1278,
      "timezone" => "Europe/London",
      "utc_offset" => "+0000",
      "currency" => "GBP",
      "currency_name" => "British Pound Sterling",
      "languages" => "en-GB,cy-GB,gd",
      "asn" => "AS15169",
      "org" => "Google LLC",
      "postal" => "EC1A",
      "country_calling_code" => "+44"
    }

    stub_request(:get, "https://ipapi.co/json/")
      .with(headers: { 'User-Agent' => 'PDFy/1.0' })
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert_equal "London", result.data[:city]
    assert_equal "United Kingdom", result.data[:country]
    assert_equal "Europe/London", result.data[:timezone]
    assert_equal 51.5074, result.data[:latitude]
    assert_equal -0.1278, result.data[:longitude]
    assert_equal "GBP", result.data[:currency]
    assert_equal "British Pound Sterling", result.data[:currency_name]
    assert_equal "en-GB,cy-GB,gd", result.data[:languages]
    assert_equal "AS15169", result.data[:asn]
    assert_equal "Google LLC", result.data[:org]
    assert_equal "EC1A", result.data[:postal]
    assert_equal "+44", result.data[:calling_code]
  end

  test "should handle different location formats" do
    mock_response = {
      "ip" => "8.8.8.8",
      "city" => "Custom City",
      "region" => "Custom Region",
      "country" => "XX",
      "country_name" => "Custom Country",
      "latitude" => 0.0,
      "longitude" => 0.0,
      "timezone" => "UTC"
    }

    stub_request(:get, "https://ipapi.co/json/")
      .with(headers: { 'User-Agent' => 'PDFy/1.0' })
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert_equal "Custom City", result.data[:city]
    assert_equal "Custom Country", result.data[:country]
    assert_equal 0.0, result.data[:latitude]
    assert_equal 0.0, result.data[:longitude]
  end

  test "should handle IPv6 addresses" do
    mock_response = {
      "ip" => "2001:4860:4860::8888",
      "city" => "Mountain View",
      "country" => "US",
      "country_name" => "United States"
    }

    stub_request(:get, "https://ipapi.co/2001:4860:4860::8888/")
      .with(headers: { 'User-Agent' => 'PDFy/1.0' })
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ "ip" => "2001:4860:4860::8888" })

    assert result.success?
    assert_equal "Mountain View", result.data[:city]
  end

  test "should include metadata in response" do
    mock_response = {
      "ip" => "8.8.8.8",
      "city" => "Mountain View",
      "country" => "US"
    }

    stub_request(:get, "https://ipapi.co/json/")
      .with(headers: { 'User-Agent' => 'PDFy/1.0' })
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert result.metadata.present?
    assert_equal "location", result.metadata[:source]
    assert_equal 200, result.metadata[:status_code]
    assert result.metadata[:timestamp].present?
  end
end