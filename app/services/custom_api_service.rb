class CustomApiService < BaseApiService
  # Generic service for custom REST APIs
  
  def make_request(parameters)
    method = (configuration['method'] || 'GET').downcase.to_sym
    headers = build_headers
    
    options = {
      headers: headers,
      timeout: configuration['timeout'] || 10
    }
    
    # Add query params for GET requests
    if method == :get && parameters.any?
      options[:query] = parameters
    end
    
    # Add body for POST/PUT requests
    if [:post, :put, :patch].include?(method) && parameters.any?
      options[:body] = parameters
      options[:headers]['Content-Type'] = 'application/json' unless options[:headers]['Content-Type']
    end
    
    HTTParty.send(method, api_endpoint, options)
  end
  
  def parse_response
    return {} unless response.parsed_response
    
    # If response is already parsed (JSON), return it
    if response.parsed_response.is_a?(Hash) || response.parsed_response.is_a?(Array)
      response.parsed_response
    else
      # Try to parse as JSON
      begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        { raw_response: response.body }
      end
    end
  end
  
  def response_successful?
    response && (200..299).include?(response.code)
  end
  
  private
  
  def build_headers
    headers = {}
    
    # Add API key if configured
    if configuration['api_key_header'].present? && api_key.present?
      headers[configuration['api_key_header']] = api_key
    end
    
    # Add custom headers
    if configuration['headers'].is_a?(Hash)
      headers.merge!(configuration['headers'])
    end
    
    headers
  end
end