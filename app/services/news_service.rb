class NewsService < BaseApiService
  # Uses NewsAPI.org (free tier available)
  # Sign up at: https://newsapi.org/register
  
  BASE_URL = "https://newsapi.org/v2"
  
  def make_request(parameters)
    endpoint = parameters[:endpoint] || 'top-headlines'
    query_params = build_query_params(parameters)
    
    url = "#{BASE_URL}/#{endpoint}"
    
    HTTParty.get(url, {
      query: query_params,
      headers: {
        'X-Api-Key' => api_key
      },
      timeout: 10
    })
  end
  
  def parse_response
    return [] unless response.parsed_response.is_a?(Hash)
    
    data = response.parsed_response
    
    if data['status'] == 'ok' && data['articles']
      parse_articles(data['articles'])
    else
      []
    end
  end
  
  def response_successful?
    response && response.code == 200 && response.parsed_response['status'] == 'ok'
  end
  
  def error_message
    if response && response.parsed_response.is_a?(Hash)
      response.parsed_response['message'] || super
    else
      super
    end
  end
  
  private
  
  def build_query_params(parameters)
    params = {}
    endpoint = parameters[:endpoint] || 'top-headlines'
    
    # For top headlines endpoint
    if endpoint == 'top-headlines'
      params[:country] = parameters[:country] || configuration['country'] || 'us'
      params[:category] = parameters[:category] if parameters[:category]
    end
    
    # For everything endpoint
    params[:q] = parameters[:query] if parameters[:query]
    params[:from] = parameters[:from] if parameters[:from]
    params[:to] = parameters[:to] if parameters[:to]
    params[:language] = parameters[:language] || configuration['language'] || 'en'
    params[:sortBy] = parameters[:sort_by] || 'publishedAt'
    params[:pageSize] = parameters[:page_size] || 5
    
    params
  end
  
  def parse_articles(articles)
    articles.first(10).map do |article|
      {
        title: article['title'],
        description: article['description'],
        url: article['url'],
        url_to_image: article['urlToImage'],
        published_at: article['publishedAt'],
        source_name: article.dig('source', 'name'),
        author: article['author'],
        content: article['content']
      }
    end
  end
end