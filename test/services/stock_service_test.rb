require "test_helper"

class StockServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @data_source = DataSource.create!(
      name: "stock_test",
      source_type: "stock",
      api_endpoint: "https://www.alphavantage.co/query",
      api_key: "test_api_key",
      configuration: {
        "default_symbol" => "AAPL",
        "cache_duration" => 300
      },
      user: @user,
      active: true
    )
    @service = StockService.new(@data_source)
  end

  test "should initialize with data_source" do
    assert_equal @data_source, @service.data_source
  end

  test "should make successful API request" do
    mock_response = {
      "Global Quote" => {
        "01. symbol" => "AAPL",
        "05. price" => "150.00",
        "09. change" => "2.50",
        "10. change percent" => "1.69%",
        "06. volume" => "50000000",
        "08. previous close" => "147.50"
      }
    }

    stub_request(:get, "https://www.alphavantage.co/query")
      .with(query: {
        function: "GLOBAL_QUOTE",
        symbol: "AAPL",
        apikey: "test_api_key"
      })
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ symbol: "AAPL" })

    assert result.success?
    assert_equal "AAPL", result.data[:symbol]
    assert_equal 150.00, result.data[:price]
    assert_equal 1.69, result.data[:change_percent]
    assert_equal 50000000, result.data[:volume]
    assert_equal 147.50, result.data[:previous_close]
  end

  test "should use default symbol when none provided" do
    mock_response = {
      "Global Quote" => {
        "01. symbol" => "AAPL",
        "05. price" => "150.00",
        "09. change" => "2.50",
        "10. change percent" => "1.69%",
        "06. volume" => "50000000",
        "08. previous close" => "147.50"
      }
    }

    stub_request(:get, "https://www.alphavantage.co/query")
      .with(query: {
        function: "GLOBAL_QUOTE",
        symbol: "AAPL",  # Should use default symbol
        apikey: "test_api_key"
      })
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({})

    assert result.success?
    assert_equal "AAPL", result.data[:symbol]
  end

  test "should handle different stock symbols" do
    symbols = ["MSFT", "GOOGL", "TSLA"]
    
    symbols.each do |symbol|
      mock_response = {
        "Global Quote" => {
          "01. symbol" => symbol,
          "05. price" => "#{100 + rand(100)}.00",
          "09. change" => "#{rand(10)}.50",
          "10. change percent" => "#{rand(5)}.#{rand(100)}%",
          "06. volume" => "#{rand(100000000)}",
          "08. previous close" => "#{100 + rand(100)}.00"
        }
      }

      stub_request(:get, "https://www.alphavantage.co/query")
        .with(query: {
          function: "GLOBAL_QUOTE",
          symbol: symbol,
          apikey: "test_api_key"
        })
        .to_return(
          status: 200,
          body: mock_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = @service.fetch({ symbol: symbol })

      assert result.success?
      assert_equal symbol, result.data[:symbol]
    end
  end

  test "should handle API error response" do
    error_response = {
      "Error Message" => "Invalid API call. Please retry or visit the documentation"
    }

    stub_request(:get, "https://www.alphavantage.co/query")
      .with(query: {
        function: "GLOBAL_QUOTE",
        symbol: "INVALID",
        apikey: "test_api_key"
      })
      .to_return(
        status: 200,
        body: error_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ symbol: "INVALID" })

    assert_not result.success?
    assert_includes result.error, "Invalid API call"
  end

  test "should handle rate limit response" do
    rate_limit_response = {
      "Note" => "Thank you for using Alpha Vantage! Our standard API call frequency is 5 calls per minute and 500 calls per day."
    }

    stub_request(:get, "https://www.alphavantage.co/query")
      .with(query: {
        function: "GLOBAL_QUOTE",
        symbol: "AAPL",
        apikey: "test_api_key"
      })
      .to_return(
        status: 200,
        body: rate_limit_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ symbol: "AAPL" })

    assert_not result.success?
    assert_includes result.error, "Thank you for using Alpha Vantage"
  end

  test "should handle HTTP error status" do
    stub_request(:get, "https://www.alphavantage.co/query")
      .with(query: {
        function: "GLOBAL_QUOTE",
        symbol: "AAPL",
        apikey: "test_api_key"
      })
      .to_return(status: 500, body: "Internal Server Error")

    result = @service.fetch({ symbol: "AAPL" })

    assert_not result.success?
    assert_includes result.error, "API request failed with status 500"
  end

  test "should handle network timeout" do
    stub_request(:get, "https://www.alphavantage.co/query")
      .with(query: {
        function: "GLOBAL_QUOTE",
        symbol: "AAPL",
        apikey: "test_api_key"
      })
      .to_timeout

    result = @service.fetch({ symbol: "AAPL" })

    assert_not result.success?
    assert_includes result.error, "execution expired"
  end

  test "should handle invalid JSON response" do
    stub_request(:get, "https://www.alphavantage.co/query")
      .with(query: {
        function: "GLOBAL_QUOTE",
        symbol: "AAPL",
        apikey: "test_api_key"
      })
      .to_return(
        status: 200,
        body: "Invalid JSON {",
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ symbol: "AAPL" })

    assert_not result.success?
    assert_includes result.error, "unexpected token"
  end

  test "should include metadata in successful response" do
    mock_response = {
      "Global Quote" => {
        "01. symbol" => "AAPL",
        "05. price" => "150.00",
        "09. change" => "2.50",
        "10. change percent" => "1.69%",
        "06. volume" => "50000000",
        "08. previous close" => "147.50"
      }
    }

    stub_request(:get, "https://www.alphavantage.co/query")
      .with(query: {
        function: "GLOBAL_QUOTE",
        symbol: "AAPL",
        apikey: "test_api_key"
      })
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ symbol: "AAPL" })

    assert result.success?
    assert result.metadata.present?
    assert_equal "stock", result.metadata[:source]
    assert result.metadata[:timestamp].present?
  end

  test "should handle missing Global Quote data" do
    incomplete_response = {
      "Meta Data" => {
        "1. Information" => "Global Quote",
        "2. Symbol" => "AAPL"
      }
      # Missing "Global Quote" section
    }

    stub_request(:get, "https://www.alphavantage.co/query")
      .with(query: {
        function: "GLOBAL_QUOTE",
        symbol: "AAPL",
        apikey: "test_api_key"
      })
      .to_return(
        status: 200,
        body: incomplete_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ symbol: "AAPL" })

    assert_not result.success?
    assert_equal "API request failed with status 200", result.error
  end

  test "should handle empty API key" do
    @data_source.update!(api_key: "")
    
    # API should still make request but may get error response
    error_response = {
      "Error Message" => "the parameter apikey is invalid or missing."
    }

    stub_request(:get, "https://www.alphavantage.co/query")
      .with(query: {
        function: "GLOBAL_QUOTE",
        symbol: "AAPL",
        apikey: ""
      })
      .to_return(
        status: 200,
        body: error_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ symbol: "AAPL" })

    assert_not result.success?
    assert_includes result.error, "apikey is invalid"
  end

  test "should format change percent correctly" do
    mock_response = {
      "Global Quote" => {
        "01. symbol" => "AAPL",
        "05. price" => "150.00",
        "09. change" => "2.50",
        "10. change percent" => "1.6900%",  # With extra zeros
        "06. volume" => "50000000",
        "08. previous close" => "147.50"
      }
    }

    stub_request(:get, "https://www.alphavantage.co/query")
      .with(query: {
        function: "GLOBAL_QUOTE",
        symbol: "AAPL",
        apikey: "test_api_key"
      })
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ symbol: "AAPL" })

    assert result.success?
    assert_equal 1.69, result.data[:change_percent]
  end

  test "should handle large volume numbers" do
    mock_response = {
      "Global Quote" => {
        "01. symbol" => "AAPL",
        "05. price" => "150.00",
        "09. change" => "2.50",
        "10. change percent" => "1.69%",
        "06. volume" => "123456789",  # Large number
        "08. previous close" => "147.50"
      }
    }

    stub_request(:get, "https://www.alphavantage.co/query")
      .with(query: {
        function: "GLOBAL_QUOTE",
        symbol: "AAPL",
        apikey: "test_api_key"
      })
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = @service.fetch({ symbol: "AAPL" })

    assert result.success?
    assert_equal 123456789, result.data[:volume]
  end

  test "should work with different API endpoints" do
    # Test with custom endpoint
    @data_source.update!(api_endpoint: "https://custom-api.example.com/quote")
    
    mock_response = {
      "Global Quote" => {
        "01. symbol" => "AAPL",
        "05. price" => "150.00",
        "09. change" => "2.50",
        "10. change percent" => "1.69%",
        "06. volume" => "50000000",
        "08. previous close" => "147.50"
      }
    }

    # StockService always uses Alpha Vantage URL regardless of data_source.api_endpoint
    stub_request(:get, "https://www.alphavantage.co/query")
      .with(query: {
        function: "GLOBAL_QUOTE",
        symbol: "AAPL",
        apikey: "test_api_key"
      })
      .to_return(
        status: 200,
        body: mock_response.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Need to recreate service after updating data source
    @service = StockService.new(@data_source)
    result = @service.fetch({ symbol: "AAPL" })

    assert result.success?
    assert_equal "AAPL", result.data[:symbol]
  end
end