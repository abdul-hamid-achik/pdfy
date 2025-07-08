require "test_helper"

class PdfGenerationFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = users(:one)
    @admin_user = admin_users(:one) if defined?(AdminUser)
  end

  test "complete PDF generation workflow for regular user" do
    sign_in @user

    # Step 1: Create a new template
    get new_pdf_template_path
    assert_response :success
    assert_select "form"

    post pdf_templates_path, params: {
      pdf_template: {
        name: "Integration Test Invoice",
        description: "Invoice template for integration testing",
        template_content: <<~'HTML',
          <div class="invoice">
            <h1>Invoice #{{invoice_number}}</h1>
            <div class="header">
              <p><strong>From:</strong> {{company_name}}</p>
              <p><strong>Date:</strong> {{invoice_date}}</p>
            </div>
            <div class="client">
              <p><strong>Bill To:</strong></p>
              <p>{{client_name}}</p>
              <p>{{client_address}}</p>
            </div>
            <table class="items">
              <tr>
                <th>Description</th>
                <th>Quantity</th>
                <th>Price</th>
                <th>Total</th>
              </tr>
              <tr>
                <td>{{item_description}}</td>
                <td>{{item_quantity}}</td>
                <td>${{item_price}}</td>
                <td>${{item_total}}</td>
              </tr>
            </table>
            <div class="total">
              <p><strong>Total: ${{grand_total}}</strong></p>
            </div>
          </div>
        HTML
        active: true
      }
    }

    assert_response :redirect
    follow_redirect!
    assert_response :success
    
    template = PdfTemplate.last
    assert_equal "Integration Test Invoice", template.name
    assert_equal @user, template.user

    # Step 2: View the template and verify variables are detected
    get pdf_template_path(template)
    assert_response :success
    assert_select "h1", "Integration Test Invoice"
    
    # Check that variables are listed
    expected_variables = %w[invoice_number company_name invoice_date client_name client_address 
                           item_description item_quantity item_price item_total grand_total]
    expected_variables.each do |var|
      assert_select "body", text: /#{var}/
    end

    # Step 3: Generate a PDF from the template
    get new_pdf_template_processed_pdf_path(template)
    assert_response :success
    assert_select "form"
    
    # Verify all variable input fields are present
    expected_variables.each do |var|
      assert_select "input[name='variables[#{var}]'], textarea[name='variables[#{var}]']"
    end

    # Step 4: Submit the form with variable values
    mock_pdf_content = "MOCK_PDF_CONTENT_FOR_INTEGRATION_TEST"
    Grover.any_instance.stubs(:to_pdf).returns(mock_pdf_content)
    
    post pdf_template_processed_pdfs_path(template), params: {
      processed_pdf: {
        metadata: { "source" => "integration_test" }
      },
      variables: {
        "invoice_number" => "INT-001",
        "company_name" => "Test Company Inc.",
        "invoice_date" => "2024-01-15",
        "client_name" => "Integration Test Client",
        "client_address" => "123 Test Street, Test City, TC 12345",
        "item_description" => "Integration Testing Services",
        "item_quantity" => "10",
        "item_price" => "150.00",
        "item_total" => "1500.00",
        "grand_total" => "1500.00"
      }
    }

    assert_response :redirect
    follow_redirect!
    assert_response :success

    # Step 5: Verify the generated PDF
    generated_pdf = ProcessedPdf.last
    assert_equal template, generated_pdf.pdf_template
    assert generated_pdf.pdf_file.attached?
    
    # Check that variables were properly substituted
    assert_includes generated_pdf.original_html, "INT-001"
    assert_includes generated_pdf.original_html, "Test Company Inc."
    assert_includes generated_pdf.original_html, "Integration Test Client"
    assert_not_includes generated_pdf.original_html, "{{invoice_number}}"

    # Step 6: Download the PDF
    get download_pdf_template_processed_pdf_path(template, generated_pdf)
    assert_response :redirect
    assert_match %r{/rails/active_storage/blobs/}, response.location

    # Step 7: Verify the PDF appears in the template's recent PDFs
    get pdf_template_path(template)
    assert_response :success
    assert_select ".processed-pdf", minimum: 1
  end

  test "admin user can access and manage all templates" do
    skip "Admin functionality not implemented" unless defined?(AdminUser) && @admin_user

    # Regular user creates a template
    sign_in @user
    post pdf_templates_path, params: {
      pdf_template: {
        name: "User Template",
        description: "Template created by regular user",
        template_content: '<h1>{{title}}</h1>',
        active: true
      }
    }
    user_template = PdfTemplate.last
    sign_out @user

    # Admin can view all templates
    sign_in @admin_user
    get pdf_templates_path
    assert_response :success
    assert_select "body", text: /User Template/

    # Admin can edit user's template
    get edit_pdf_template_path(user_template)
    assert_response :success

    patch pdf_template_path(user_template), params: {
      pdf_template: {
        name: "Admin Modified Template",
        description: "Modified by admin"
      }
    }
    assert_response :redirect
    
    user_template.reload
    assert_equal "Admin Modified Template", user_template.name
  end

  test "user cannot access other user's templates" do
    other_user = users(:two)
    
    # Other user creates a template
    sign_in other_user
    post pdf_templates_path, params: {
      pdf_template: {
        name: "Private Template",
        description: "Should not be accessible to other users",
        template_content: '<h1>{{secret}}</h1>',
        active: true
      }
    }
    private_template = PdfTemplate.last
    sign_out other_user

    # Current user should not be able to access it
    sign_in @user
    
    get pdf_templates_path
    assert_response :success
    assert_select "body", { text: /Private Template/, count: 0 }

    assert_raises(ActiveRecord::RecordNotFound) do
      get pdf_template_path(private_template)
    end

    assert_raises(ActiveRecord::RecordNotFound) do
      get edit_pdf_template_path(private_template)
    end
  end

  test "PDF generation with missing variables" do
    sign_in @user

    template = PdfTemplate.create!(
      name: "Incomplete Variables Test",
      description: "Test template with missing variables",
      template_content: <<~'HTML',
        <div>
          <h1>{{title}}</h1>
          <p>Required field: {{required_field}}</p>
          <p>Optional field: {{optional_field}}</p>
        </div>
      HTML
      user: @user,
      active: true
    )

    mock_pdf_content = "PDF_WITH_MISSING_VARS"
    Grover.any_instance.stubs(:to_pdf).returns(mock_pdf_content)
    
    post pdf_template_processed_pdfs_path(template), params: {
      processed_pdf: {},
      variables: {
        "title" => "Test Document",
        "required_field" => "This is provided"
        # optional_field is missing
      }
    }

    assert_response :redirect
    follow_redirect!
    assert_response :success

    generated_pdf = ProcessedPdf.last
    assert_includes generated_pdf.original_html, "Test Document"
    assert_includes generated_pdf.original_html, "This is provided"
    assert_includes generated_pdf.original_html, "{{optional_field}}"  # Should remain unreplaced
  end

  test "PDF generation error handling" do
    sign_in @user

    template = PdfTemplate.create!(
      name: "Error Test Template",
      description: "Template for testing error handling",
      template_content: '<h1>{{title}}</h1>',
      user: @user,
      active: true
    )

    # Mock Grover to raise an error
    Grover.any_instance.stubs(:to_pdf).raises(StandardError, "Simulated PDF generation error")
    
    post pdf_template_processed_pdfs_path(template), params: {
      processed_pdf: {},
      variables: { "title" => "Error Test" }
    }

    assert_response :unprocessable_entity
    assert_select "div.alert", text: /Error generating PDF: Simulated PDF generation error/
    
    # Should still be on the new PDF page with form
    assert_select "form[action=?]", pdf_template_processed_pdfs_path(template)
    assert_select "input[name='variables[title]'][value='Error Test']"  # Should preserve form data
  end

  test "template with complex HTML and CSS classes" do
    sign_in @user

    template = PdfTemplate.create!(
      name: "Complex HTML Template",
      description: "Template with complex HTML structure and CSS classes",
      template_content: <<~'HTML',
        <div class="container mx-auto p-8">
          <header class="text-center mb-8">
            <h1 class="text-4xl font-bold text-blue-600">{{company_name}}</h1>
            <p class="text-gray-600">{{company_tagline}}</p>
          </header>
          
          <section class="grid grid-cols-2 gap-8 mb-8">
            <div class="bg-gray-100 p-4 rounded">
              <h2 class="text-xl font-semibold mb-4">Bill To:</h2>
              <div class="space-y-2">
                <p class="font-medium">{{client_name}}</p>
                <p class="text-sm text-gray-600">{{client_email}}</p>
                <p class="text-sm">{{client_address}}</p>
              </div>
            </div>
            
            <div class="bg-blue-50 p-4 rounded">
              <h2 class="text-xl font-semibold mb-4">Invoice Details:</h2>
              <div class="space-y-2">
                <p><span class="font-medium">Invoice #:</span> {{invoice_number}}</p>
                <p><span class="font-medium">Date:</span> {{invoice_date}}</p>
                <p><span class="font-medium">Due Date:</span> {{due_date}}</p>
              </div>
            </div>
          </section>
          
          <table class="w-full border-collapse border border-gray-300">
            <thead class="bg-gray-200">
              <tr>
                <th class="border border-gray-300 p-3 text-left">Description</th>
                <th class="border border-gray-300 p-3 text-right">Quantity</th>
                <th class="border border-gray-300 p-3 text-right">Rate</th>
                <th class="border border-gray-300 p-3 text-right">Amount</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td class="border border-gray-300 p-3">{{service_description}}</td>
                <td class="border border-gray-300 p-3 text-right">{{service_quantity}}</td>
                <td class="border border-gray-300 p-3 text-right">${{service_rate}}</td>
                <td class="border border-gray-300 p-3 text-right">${{service_total}}</td>
              </tr>
            </tbody>
          </table>
          
          <div class="mt-8 text-right">
            <div class="inline-block bg-green-50 p-4 rounded">
              <p class="text-2xl font-bold text-green-800">Total: ${{grand_total}}</p>
            </div>
          </div>
          
          <footer class="mt-12 text-center text-gray-500 text-sm">
            <p>{{footer_text}}</p>
          </footer>
        </div>
      HTML
      user: @user,
      active: true
    )

    mock_pdf_content = "COMPLEX_HTML_PDF"
    generated_html = nil
    
    Grover.any_instance.stubs(:to_pdf).with do |html_content|
      generated_html = html_content
      true
    end.returns(mock_pdf_content)

    post pdf_template_processed_pdfs_path(template), params: {
      processed_pdf: {},
      variables: {
        "company_name" => "Advanced Solutions Inc.",
        "company_tagline" => "Innovation Through Technology",
        "client_name" => "Tech Startup LLC",
        "client_email" => "billing@techstartup.com",
        "client_address" => "456 Innovation Drive, Tech City, TC 54321",
        "invoice_number" => "ADV-2024-001",
        "invoice_date" => "2024-01-15",
        "due_date" => "2024-02-14",
        "service_description" => "Custom Software Development",
        "service_quantity" => "40",
        "service_rate" => "125.00",
        "service_total" => "5000.00",
        "grand_total" => "5000.00",
        "footer_text" => "Thank you for your business! Payment terms: Net 30 days."
      }
    }

    assert_response :redirect
    follow_redirect!
    assert_response :success

    # Verify the generated HTML includes Tailwind CSS
    assert_not_nil generated_html
    assert_includes generated_html, "tailwindcss.com"
    assert_includes generated_html, "Advanced Solutions Inc."
    assert_includes generated_html, "text-4xl font-bold text-blue-600"
    assert_includes generated_html, "Custom Software Development"

    # Verify the processed PDF was created correctly
    generated_pdf = ProcessedPdf.last
    assert_includes generated_pdf.original_html, "Advanced Solutions Inc."
    assert_includes generated_pdf.original_html, "Tech Startup LLC"
    assert_not_includes generated_pdf.original_html, "{{company_name}}"
  end

  test "template listing and pagination behavior" do
    sign_in @user

    # Create multiple templates to test listing
    15.times do |i|
      PdfTemplate.create!(
        name: "Template #{i.to_s.rjust(2, '0')}",
        description: "Description for template #{i}",
        template_content: '<h1>Template {{number}}</h1>',
        user: @user,
        active: i.even?,  # Make some active, some inactive
        created_at: i.hours.ago
      )
    end

    get pdf_templates_path
    assert_response :success

    # Should show templates ordered by creation date (newest first)
    response_body = response.body
    template_14_pos = response_body.index("Template 14")
    template_00_pos = response_body.index("Template 00")
    
    assert template_14_pos < template_00_pos, "Newer templates should appear first"

    # Should show both active and inactive templates
    assert_select "body", text: /Template 14/  # Active (even number)
    assert_select "body", text: /Template 13/  # Inactive (odd number)
  end

  test "data source integration with PDF generation" do
    sign_in @user

    # Create a data source
    data_source = DataSource.create!(
      name: "weather_integration",
      source_type: "weather",
      api_endpoint: "https://api.example.com/weather",
      api_key: "test_key",
      user: @user,
      active: true
    )

    # Add some data to the data source
    data_source.data_points.create!(
      key: "current_weather",
      value: {
        "temperature" => 22,
        "condition" => "sunny",
        "humidity" => 65,
        "location" => "Test City"
      },
      fetched_at: Time.current,
      expires_at: 1.hour.from_now
    )

    # Create a template that could use weather data
    template = PdfTemplate.create!(
      name: "Weather Report Template",
      description: "Template that includes weather information",
      template_content: <<~'HTML',
        <div class="weather-report">
          <h1>Weather Report for {{location}}</h1>
          <div class="current-conditions">
            <p><strong>Temperature:</strong> {{temperature}}°C</p>
            <p><strong>Condition:</strong> {{condition}}</p>
            <p><strong>Humidity:</strong> {{humidity}}%</p>
          </div>
          <div class="report-info">
            <p><strong>Report Date:</strong> {{report_date}}</p>
            <p><strong>Generated for:</strong> {{client_name}}</p>
          </div>
        </div>
      HTML
      user: @user,
      active: true
    )

    mock_pdf_content = "WEATHER_REPORT_PDF"
    Grover.any_instance.stubs(:to_pdf).returns(mock_pdf_content)
    
    post pdf_template_processed_pdfs_path(template), params: {
      processed_pdf: {
        metadata: { "data_source_id" => data_source.id }
      },
      variables: {
        "location" => "Test City",
        "temperature" => "22",
        "condition" => "sunny",
        "humidity" => "65",
        "report_date" => "2024-01-15",
        "client_name" => "Weather Service Client"
      }
    }

    assert_response :redirect
    follow_redirect!
    assert_response :success

    generated_pdf = ProcessedPdf.last
    assert_includes generated_pdf.original_html, "Test City"
    assert_includes generated_pdf.original_html, "22°C"
    assert_includes generated_pdf.original_html, "sunny"
    assert_equal data_source.id.to_s, generated_pdf.metadata["data_source_id"]
  end
end