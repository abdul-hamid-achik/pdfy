class WeatherService < BaseApiService
  # Uses OpenWeatherMap API (free tier available)
  # Sign up at: https://openweathermap.org/api
  
  BASE_URL = "https://api.openweathermap.org/data/2.5"
  
  def make_request(parameters)
    city = parameters[:city] || configuration['default_city'] || 'London'
    units = parameters[:units] || configuration['units'] || 'metric'
    
    url = "#{BASE_URL}/weather"
    
    HTTParty.get(url, {
      query: {
        q: city,
        appid: api_key,
        units: units
      },
      timeout: 10
    })
  end
  
  def parse_response
    return {} unless response.parsed_response.is_a?(Hash)
    
    data = response.parsed_response
    
    {
      city: data.dig('name'),
      country: data.dig('sys', 'country'),
      temp: data.dig('main', 'temp'),
      feels_like: data.dig('main', 'feels_like'),
      temp_min: data.dig('main', 'temp_min'),
      temp_max: data.dig('main', 'temp_max'),
      pressure: data.dig('main', 'pressure'),
      humidity: data.dig('main', 'humidity'),
      condition: data.dig('weather', 0, 'main'),
      description: data.dig('weather', 0, 'description'),
      icon: data.dig('weather', 0, 'icon'),
      wind_speed: data.dig('wind', 'speed'),
      wind_deg: data.dig('wind', 'deg'),
      clouds: data.dig('clouds', 'all'),
      sunrise: format_time(data.dig('sys', 'sunrise')),
      sunset: format_time(data.dig('sys', 'sunset')),
      timezone: data.dig('timezone')
    }
  end
  
  def response_successful?
    response && response.code == 200
  end
  
  def error_message
    if response && response.parsed_response.is_a?(Hash)
      response.parsed_response['message'] || super
    else
      super
    end
  end
  
  private
  
  def format_time(timestamp)
    return nil unless timestamp
    Time.at(timestamp).strftime('%H:%M')
  end
end