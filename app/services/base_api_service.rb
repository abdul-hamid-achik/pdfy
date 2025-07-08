class BaseApiService
  attr_reader :data_source, :response
  
  Result = Struct.new(:success?, :data, :error, :metadata, keyword_init: true)
  
  def initialize(data_source)
    @data_source = data_source
  end
  
  def fetch(parameters = {})
    begin
      @response = make_request(parameters)
      
      if response_successful?
        Result.new(
          success?: true,
          data: parse_response,
          metadata: response_metadata
        )
      else
        Result.new(
          success?: false,
          error: error_message,
          metadata: response_metadata
        )
      end
    rescue StandardError => e
      Rails.logger.error "API request failed: #{e.message}"
      Result.new(
        success?: false,
        error: e.message,
        metadata: { error_class: e.class.name }
      )
    end
  end
  
  protected
  
  def make_request(parameters)
    raise NotImplementedError, "Subclasses must implement make_request"
  end
  
  def parse_response
    raise NotImplementedError, "Subclasses must implement parse_response"
  end
  
  def response_successful?
    response && response.code == 200
  end
  
  def error_message
    "API request failed with status #{response&.code}"
  end
  
  def response_metadata
    {
      status_code: response&.code,
      fetched_at: Time.current,
      source: self.class.name
    }
  end
  
  def api_key
    data_source.api_key
  end
  
  def api_endpoint
    data_source.api_endpoint
  end
  
  def configuration
    data_source.configuration || {}
  end
end