require "test_helper"

class PdfTemplateTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com", password: "password")
    @template = PdfTemplate.create!(
      name: "Test Template",
      template_content: "Hello {{name}}, the weather is {{weather.temp}}°C",
      user: @user
    )
  end

  test "should extract variable names" do
    assert_equal ["name", "weather.temp"], @template.variable_names.sort
  end

  test "should render with simple variables" do
    result = @template.render_with_variables(name: "John")
    assert_includes result, "Hello John"
  end

  test "should handle missing variables" do
    result = @template.render_with_variables({})
    assert_includes result, "{{name}}"
  end

  test "should fetch dynamic data from data sources" do
    # Create a mock data source
    weather_source = @user.data_sources.create!(
      name: "weather",
      source_type: "weather",
      api_endpoint: "https://api.example.com",
      active: true
    )
    
    @template.template_data_sources.create!(
      data_source: weather_source,
      enabled: true
    )
    
    # Mock the data fetching
    weather_source.stubs(:cached_data).returns({ "temp" => 25 })
    
    dynamic_data = @template.fetch_dynamic_data
    assert_equal 25, dynamic_data["weather.temp"]
  end
end