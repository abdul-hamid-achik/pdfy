class LocationService < BaseApiService
  # Uses ipapi.co (free tier available, no API key required for basic usage)
  # For more requests, sign up at: https://ipapi.co/
  
  BASE_URL = "https://ipapi.co"
  
  def make_request(parameters)
    ip_address = parameters[:ip] || 'json' # 'json' gets current IP
    format = parameters[:format] || 'json'
    
    url = "#{BASE_URL}/#{ip_address}/"
    
    HTTParty.get(url, {
      headers: {
        'User-Agent' => 'PDFy/1.0'
      },
      timeout: 10
    })
  end
  
  def parse_response
    return {} unless response.parsed_response.is_a?(Hash)
    
    data = response.parsed_response
    
    {
      ip: data['ip'],
      city: data['city'],
      region: data['region'],
      region_code: data['region_code'],
      country: data['country_name'],
      country_code: data['country_code'],
      country_capital: data['country_capital'],
      country_area: data['country_area'],
      country_population: data['country_population'],
      continent: data['continent_code'],
      latitude: data['latitude'],
      longitude: data['longitude'],
      timezone: data['timezone'],
      utc_offset: data['utc_offset'],
      currency: data['currency'],
      currency_name: data['currency_name'],
      languages: data['languages'],
      asn: data['asn'],
      org: data['org'],
      postal: data['postal'],
      calling_code: data['country_calling_code']
    }
  end
  
  def response_successful?
    response && response.code == 200 && !response.parsed_response['error']
  end
  
  def error_message
    if response && response.parsed_response.is_a?(Hash) && response.parsed_response['reason']
      response.parsed_response['reason']
    else
      super
    end
  end
end