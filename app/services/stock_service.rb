class StockService < BaseApiService
  # Uses Alpha Vantage API (free tier available)
  # Sign up at: https://www.alphavantage.co/support/#api-key
  
  BASE_URL = "https://www.alphavantage.co/query"
  
  def make_request(parameters)
    symbol = parameters[:symbol] || configuration['default_symbol'] || 'AAPL'
    function = parameters[:function] || 'GLOBAL_QUOTE'
    
    HTTParty.get(BASE_URL, {
      query: {
        function: function,
        symbol: symbol,
        apikey: api_key
      },
      timeout: 10
    })
  end
  
  def parse_response
    return {} unless response.parsed_response.is_a?(Hash)
    
    data = response.parsed_response
    
    if data['Global Quote']
      parse_quote_data(data['Global Quote'])
    elsif data['Error Message']
      { error: data['Error Message'] }
    elsif data['Note']
      { error: 'API rate limit reached', note: data['Note'] }
    else
      { error: 'No Global Quote data found' }
    end
  end
  
  def response_successful?
    response && response.code == 200 && !response.parsed_response['Error Message'] && !response.parsed_response['Note'] && response.parsed_response['Global Quote']
  end
  
  def error_message
    if response && response.parsed_response.is_a?(Hash)
      response.parsed_response['Error Message'] || 
      response.parsed_response['Note'] || 
      super
    else
      super
    end
  end
  
  private
  
  def parse_quote_data(quote)
    {
      symbol: quote['01. symbol'],
      price: quote['05. price']&.to_f,
      open: quote['02. open']&.to_f,
      high: quote['03. high']&.to_f,
      low: quote['04. low']&.to_f,
      volume: quote['06. volume']&.to_i,
      latest_trading_day: quote['07. latest trading day'],
      previous_close: quote['08. previous close']&.to_f,
      change: quote['09. change']&.to_f,
      change_percent: quote['10. change percent']&.gsub('%', '')&.to_f
    }
  end
end