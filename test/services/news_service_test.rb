require "test_helper"

class NewsServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @data_source = DataSource.create!(
      name: "news_test",
      source_type: "news",
      api_endpoint: "https://newsapi.org/v2/top-headlines",
      api_key: "test_news_api_key",
      configuration: {
        "country" => "us",
        "category" => "technology",
        "page_size" => 5
      },
      user: @user,
      active: true
    )
    @service = NewsService.new(@data_source)
  end

  test "should make successful API request" do
    mock_response = {
      "status" => "ok",
      "totalResults" => 2,
      "articles" => [
        {
          "source" => { "id" => "techcrunch", "name" => "TechCrunch" },
          "title" => "New AI breakthrough announced",
          "description" => "Scientists announce major AI breakthrough",
          "url" => "https://example.com/ai-breakthrough",
          "publishedAt" => "2024-01-15T10:30:00Z"
        },
        {
          "source" => { "id" => "wired", "name" => "Wired" },
          "title" => "The future of technology",
          "description" => "Exploring what's next in tech",
          "url" => "https://example.com/future-tech",
          "publishedAt" => "2024-01-15T09:15:00Z"
        }
      ]
    }

    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .with(
        query: {
          country: "us",
          category: "technology",
          pageSize: "5",
          apiKey: "test_news_api_key"
        },
        headers: { 'User-Agent' => 'PDFy/1.0' }
      )
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert_equal 2, result.data["articles"].length
    assert_equal "New AI breakthrough announced", result.data["articles"][0]["title"]
    assert_equal "TechCrunch", result.data["articles"][0]["source"]
  end

  test "should use custom query parameters" do
    mock_response = {
      "status" => "ok",
      "totalResults" => 1,
      "articles" => [
        {
          "source" => { "id" => "bbc-news", "name" => "BBC News" },
          "title" => "Breaking: Important news",
          "description" => "This is breaking news",
          "url" => "https://example.com/breaking",
          "publishedAt" => "2024-01-15T12:00:00Z"
        }
      ]
    }

    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .with(
        query: {
          q: "bitcoin",
          category: "business",
          pageSize: "3",
          apiKey: "test_news_api_key"
        },
        headers: { 'User-Agent' => 'PDFy/1.0' }
      )
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({
      "query" => "bitcoin",
      "category" => "business",
      "page_size" => 3
    })

    assert result.success?
    assert_equal 1, result.data["articles"].length
    assert_equal "Breaking: Important news", result.data["articles"][0]["title"]
  end

  test "should handle API error response" do
    error_response = {
      "status" => "error",
      "code" => "apiKeyInvalid",
      "message" => "Your API key is invalid or incorrect."
    }

    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .to_return(
        status: 401,
        body: error_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error, "apiKeyInvalid"
    assert_includes result.error, "API key is invalid"
  end

  test "should handle rate limiting" do
    error_response = {
      "status" => "error",
      "code" => "rateLimited",
      "message" => "You have made too many requests recently."
    }

    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .to_return(
        status: 429,
        body: error_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error, "rateLimited"
  end

  test "should include metadata in response" do
    mock_response = {
      "status" => "ok",
      "totalResults" => 1,
      "articles" => [
        {
          "source" => { "id" => "techcrunch", "name" => "TechCrunch" },
          "title" => "Test article",
          "description" => "Test description",
          "url" => "https://example.com/test",
          "publishedAt" => "2024-01-15T10:30:00Z"
        }
      ]
    }

    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert result.metadata.present?
    assert_equal "newsapi", result.metadata["source"]
    assert result.metadata["timestamp"].present?
    assert_equal 1, result.metadata["total_results"]
  end

  test "should handle missing articles" do
    response_without_articles = {
      "status" => "ok",
      "totalResults" => 0
    }

    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .to_return(
        status: 200,
        body: response_without_articles.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error, "No articles"
  end

  test "should filter out articles with missing data" do
    mock_response = {
      "status" => "ok",
      "totalResults" => 3,
      "articles" => [
        {
          "source" => { "id" => "techcrunch", "name" => "TechCrunch" },
          "title" => "Complete article",
          "description" => "This has all data",
          "url" => "https://example.com/complete",
          "publishedAt" => "2024-01-15T10:30:00Z"
        },
        {
          "source" => { "id" => nil, "name" => nil },
          "title" => nil,  # Missing title
          "description" => "Incomplete article",
          "url" => "https://example.com/incomplete",
          "publishedAt" => "2024-01-15T09:30:00Z"
        },
        {
          "source" => { "id" => "wired", "name" => "Wired" },
          "title" => "Another complete article",
          "description" => "This also has all data",
          "url" => "https://example.com/another",
          "publishedAt" => "2024-01-15T08:30:00Z"
        }
      ]
    }

    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert_equal 2, result.data["articles"].length  # Should filter out incomplete article
    assert_equal "Complete article", result.data["articles"][0]["title"]
    assert_equal "Another complete article", result.data["articles"][1]["title"]
  end

  test "should handle different categories" do
    categories = ["business", "entertainment", "health", "science", "sports", "technology"]
    
    categories.each do |category|
      mock_response = {
        "status" => "ok",
        "totalResults" => 1,
        "articles" => [
          {
            "source" => { "id" => "example", "name" => "Example News" },
            "title" => "#{category.capitalize} news",
            "description" => "News about #{category}",
            "url" => "https://example.com/#{category}",
            "publishedAt" => "2024-01-15T10:30:00Z"
          }
        ]
      }

      stub_request(:get, "https://newsapi.org/v2/top-headlines")
        .with(query: hash_including(category: category))
        .to_return(
          status: 200,
          body: mock_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = @service.fetch({ "category" => category })

      assert result.success?
      assert_equal "#{category.capitalize} news", result.data["articles"][0]["title"]
    end
  end

  test "should handle network errors" do
    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .to_raise(SocketError.new("Network unreachable"))

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error, "Network unreachable"
  end

  test "should handle timeout errors" do
    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .to_timeout

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error.downcase, "timeout"
  end

  test "should handle invalid JSON response" do
    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .to_return(
        status: 200,
        body: "Invalid JSON {",
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error.downcase, "json"
  end

  test "should format articles correctly" do
    mock_response = {
      "status" => "ok",
      "totalResults" => 1,
      "articles" => [
        {
          "source" => { "id" => "techcrunch", "name" => "TechCrunch" },
          "author" => "John Doe",
          "title" => "Amazing Technology Breakthrough",
          "description" => "Scientists have made an incredible discovery",
          "url" => "https://techcrunch.com/2024/01/15/breakthrough",
          "urlToImage" => "https://example.com/image.jpg",
          "publishedAt" => "2024-01-15T10:30:00Z",
          "content" => "The full content of the article..."
        }
      ]
    }

    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    article = result.data["articles"][0]
    
    assert_equal "Amazing Technology Breakthrough", article["title"]
    assert_equal "Scientists have made an incredible discovery", article["description"]
    assert_equal "https://techcrunch.com/2024/01/15/breakthrough", article["url"]
    assert_equal "TechCrunch", article["source"]
    assert_equal "2024-01-15T10:30:00Z", article["published_at"]
  end

  test "should handle custom endpoint" do
    @data_source.update!(api_endpoint: "https://custom-news-api.com/headlines")
    
    mock_response = {
      "status" => "ok",
      "totalResults" => 1,
      "articles" => [
        {
          "source" => { "id" => "custom", "name" => "Custom News" },
          "title" => "Custom news article",
          "description" => "From custom endpoint",
          "url" => "https://example.com/custom",
          "publishedAt" => "2024-01-15T10:30:00Z"
        }
      ]
    }

    stub_request(:get, "https://custom-news-api.com/headlines")
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert_equal "Custom news article", result.data["articles"][0]["title"]
  end
end