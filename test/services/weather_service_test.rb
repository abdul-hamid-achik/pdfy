require "test_helper"
require "webmock/minitest"

class WeatherServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com", password: "password")
    @data_source = @user.data_sources.create!(
      name: "weather",
      source_type: "weather",
      api_endpoint: "https://api.openweathermap.org/data/2.5/weather",
      api_key: "test_key",
      configuration: { "default_city" => "London" }
    )
    @service = WeatherService.new(@data_source)
  end

  test "should fetch weather data successfully" do
    stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
      .with(query: { q: "London", appid: "test_key", units: "metric" })
      .to_return(
        status: 200,
        body: {
          name: "London",
          sys: { country: "GB" },
          main: {
            temp: 20.5,
            feels_like: 19.8,
            humidity: 65
          },
          weather: [{
            main: "Clouds",
            description: "scattered clouds"
          }],
          wind: { speed: 3.5 }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch(city: "London")
    
    assert result.success?
    assert_equal "London", result.data[:city]
    assert_equal 20.5, result.data[:temp]
    assert_equal "Clouds", result.data[:condition]
    assert_equal 65, result.data[:humidity]
  end

  test "should handle API errors" do
    stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
      .with(query: { q: "InvalidCity", appid: "test_key", units: "metric" })
      .to_return(
        status: 404,
        body: { message: "city not found" }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch(city: "InvalidCity")
    
    refute result.success?
    assert_equal "city not found", result.error
  end

  test "should handle network errors" do
    stub_request(:get, "https://api.openweathermap.org/data/2.5/weather")
      .to_timeout

    result = @service.fetch(city: "London")
    
    refute result.success?
    assert_includes result.error, "execution expired"
  end
end