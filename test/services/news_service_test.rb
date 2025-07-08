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
          language: "en",
          pageSize: 5,
          sortBy: "publishedAt"
        },
        headers: { 'X-Api-Key' => 'test_news_api_key' }
      )
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert_equal 2, result.data.length
    assert_equal "New AI breakthrough announced", result.data[0][:title]
    assert_equal "TechCrunch", result.data[0][:source_name]
  end

  test "should use custom query parameters" do
    mock_response = {
      "status" => "ok",
      "totalResults" => 1,
      "articles" => [
        {
          "source" => { "id" => "bbc", "name" => "BBC" },
          "title" => "UK Tech News",
          "description" => "Latest from UK tech scene",
          "url" => "https://example.com/uk-tech",
          "publishedAt" => "2024-01-15T14:00:00Z"
        }
      ]
    }

    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .with(
        query: {
          country: "gb",
          category: "business",
          language: "en",
          pageSize: 10,
          sortBy: "publishedAt"
        },
        headers: { 'X-Api-Key' => 'test_news_api_key' }
      )
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ country: "gb", category: "business", page_size: 10 })

    assert result.success?
    assert_equal 1, result.data.length
    assert_equal "UK Tech News", result.data[0][:title]
  end

  test "should handle search queries" do
    mock_response = {
      "status" => "ok",
      "totalResults" => 1,
      "articles" => [
        {
          "source" => { "id" => nil, "name" => "Example News" },
          "title" => "AI Search Result",
          "description" => "Article about AI",
          "url" => "https://example.com/ai-search",
          "publishedAt" => "2024-01-15T12:00:00Z"
        }
      ]
    }

    stub_request(:get, "https://newsapi.org/v2/everything")
      .with(
        query: {
          q: "artificial intelligence",
          language: "en",
          sortBy: "publishedAt",
          pageSize: 5
        },
        headers: { 'X-Api-Key' => 'test_news_api_key' }
      )
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ endpoint: "everything", query: "artificial intelligence" })

    assert result.success?
    assert_equal 1, result.data.length
    assert_equal "AI Search Result", result.data[0][:title]
  end

  test "should handle empty results" do
    mock_response = {
      "status" => "ok",
      "totalResults" => 0,
      "articles" => []
    }

    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .with(
        query: {
          country: "us",
          language: "en",
          pageSize: 5,
          sortBy: "publishedAt"
        },
        headers: { 'X-Api-Key' => 'test_news_api_key' }
      )
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert_equal [], result.data
  end

  test "should handle API errors" do
    error_response = {
      "status" => "error",
      "code" => "apiKeyInvalid",
      "message" => "Your API key is invalid or incorrect."
    }

    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .with(
        query: {
          country: "us",
          language: "en",
          pageSize: 5,
          sortBy: "publishedAt"
        },
        headers: { 'X-Api-Key' => 'test_news_api_key' }
      )
      .to_return(
        status: 401,
        body: error_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error, "Your API key is invalid"
  end

  test "should handle network errors" do
    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .with(
        query: {
          country: "us",
          language: "en",
          pageSize: 5,
          sortBy: "publishedAt"
        },
        headers: { 'X-Api-Key' => 'test_news_api_key' }
      )
      .to_raise(Net::OpenTimeout)

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error, "execution expired"
  end

  test "should handle timeout errors" do
    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .with(
        query: {
          country: "us",
          language: "en",
          pageSize: 5,
          sortBy: "publishedAt"
        },
        headers: { 'X-Api-Key' => 'test_news_api_key' }
      )
      .to_timeout

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error.downcase, "timeout"
  end

  test "should parse article data correctly" do
    mock_response = {
      "status" => "ok",
      "totalResults" => 1,
      "articles" => [
        {
          "source" => { "id" => "test-source", "name" => "Test Source" },
          "author" => "John Doe",
          "title" => "Test Article",
          "description" => "Test description",
          "url" => "https://example.com/test",
          "urlToImage" => "https://example.com/image.jpg",
          "publishedAt" => "2024-01-15T10:00:00Z",
          "content" => "Full article content here..."
        }
      ]
    }

    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .with(
        query: {
          country: "us",
          language: "en",
          pageSize: 5,
          sortBy: "publishedAt"
        },
        headers: { 'X-Api-Key' => 'test_news_api_key' }
      )
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    article = result.data[0]
    assert_equal "Test Article", article[:title]
    assert_equal "Test description", article[:description]
    assert_equal "https://example.com/test", article[:url]
    assert_equal "https://example.com/image.jpg", article[:url_to_image]
    assert_equal "2024-01-15T10:00:00Z", article[:published_at]
    assert_equal "Test Source", article[:source_name]
    assert_equal "John Doe", article[:author]
    assert_equal "Full article content here...", article[:content]
  end

  test "should limit articles to 10" do
    articles = 15.times.map do |i|
      {
        "source" => { "id" => "source-#{i}", "name" => "Source #{i}" },
        "title" => "Article #{i}",
        "description" => "Description #{i}",
        "url" => "https://example.com/#{i}",
        "publishedAt" => "2024-01-15T10:00:00Z"
      }
    end

    mock_response = {
      "status" => "ok",
      "totalResults" => 15,
      "articles" => articles
    }

    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .with(
        query: {
          country: "us",
          language: "en",
          pageSize: 5,
          sortBy: "publishedAt"
        },
        headers: { 'X-Api-Key' => 'test_news_api_key' }
      )
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert_equal 10, result.data.length  # Should be limited to 10
  end

  test "should handle invalid JSON response" do
    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .with(
        query: {
          country: "us",
          language: "en",
          pageSize: 5,
          sortBy: "publishedAt"
        },
        headers: { 'X-Api-Key' => 'test_news_api_key' }
      )
      .to_return(
        status: 200,
        body: "Invalid JSON {",
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert_not result.success?
    assert_includes result.error.downcase, "json"
  end

  test "should handle date range parameters" do
    mock_response = {
      "status" => "ok",
      "totalResults" => 1,
      "articles" => [
        {
          "source" => { "id" => "dated", "name" => "Dated News" },
          "title" => "Date Range Article",
          "description" => "Article within date range",
          "url" => "https://example.com/dated",
          "publishedAt" => "2024-01-10T10:00:00Z"
        }
      ]
    }

    stub_request(:get, "https://newsapi.org/v2/everything")
      .with(
        query: {
          q: "technology",
          from: "2024-01-01",
          to: "2024-01-31",
          language: "en",
          sortBy: "publishedAt",
          pageSize: 5
        },
        headers: { 'X-Api-Key' => 'test_news_api_key' }
      )
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({
      endpoint: "everything",
      query: "technology",
      from: "2024-01-01",
      to: "2024-01-31"
    })

    assert result.success?
    assert_equal 1, result.data.length
    assert_equal "Date Range Article", result.data[0][:title]
  end

  test "should include metadata in response" do
    mock_response = {
      "status" => "ok",
      "totalResults" => 1,
      "articles" => [
        {
          "source" => { "id" => "test", "name" => "Test" },
          "title" => "Test",
          "url" => "https://example.com/test",
          "publishedAt" => "2024-01-15T10:00:00Z"
        }
      ]
    }

    stub_request(:get, "https://newsapi.org/v2/top-headlines")
      .with(
        query: {
          country: "us",
          language: "en",
          pageSize: 5,
          sortBy: "publishedAt"
        },
        headers: { 'X-Api-Key' => 'test_news_api_key' }
      )
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert result.metadata.present?
    assert_equal "news", result.metadata[:source]
    assert_equal 200, result.metadata[:status_code]
    assert result.metadata[:timestamp].present?
  end
end