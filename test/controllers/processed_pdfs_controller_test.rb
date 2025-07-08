require "test_helper"

class ProcessedPdfsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = users(:one)
    @pdf_template = pdf_templates(:one)
    @processed_pdf = @pdf_template.processed_pdfs.create!(
      original_html: "<div><h1>Invoice #001</h1><p>Bill to: John Doe</p></div>",
      variables_used: { "invoice_number" => "001", "customer_name" => "John Doe" }
    )
    # Attach a dummy PDF file
    @processed_pdf.pdf_file.attach(
      io: StringIO.new("Dummy PDF content"),
      filename: "invoice_001.pdf",
      content_type: "application/pdf"
    )
  end

  test "should redirect to login when not authenticated" do
    get pdf_template_processed_pdf_url(@pdf_template, @processed_pdf)
    assert_redirected_to new_user_session_path
  end

  test "should show processed pdf when authenticated" do
    sign_in @user
    get pdf_template_processed_pdf_url(@pdf_template, @processed_pdf)
    assert_response :success
    assert_select "h1", /PDF: monthly-report_\d{8}_\d{6}\.pdf/
  end

  test "should get new" do
    sign_in @user
    get new_pdf_template_processed_pdf_url(@pdf_template)
    assert_response :success
    assert_select "h1", "Generate New PDF"
    assert_select "form[action=?]", pdf_template_processed_pdfs_path(@pdf_template)
  end

  test "should display template variables on new page" do
    sign_in @user
    get new_pdf_template_processed_pdf_url(@pdf_template)
    assert_response :success
    
    # Should show form fields for each variable
    assert_select "input[name='variables[invoice_number]']"
    assert_select "input[name='variables[customer_name]']"
    assert_select "input[name='variables[amount]']"
    assert_select "input[name='variables[due_date]']"
  end

  test "should create processed pdf with valid params" do
    sign_in @user
    
    # Mock Grover to avoid actual PDF generation
    mock_pdf_content = "PDF_CONTENT"
    Grover.any_instance.stub(:to_pdf, mock_pdf_content) do
      assert_difference("ProcessedPdf.count") do
        post pdf_template_processed_pdfs_url(@pdf_template), params: {
          processed_pdf: {
            metadata: { "source" => "test" }
          },
          variables: {
            "invoice_number" => "002",
            "customer_name" => "Jane Smith",
            "amount" => "1500.00",
            "due_date" => "2024-02-15"
          }
        }
      end
    end

    assert_redirected_to pdf_template_processed_pdf_url(@pdf_template, ProcessedPdf.last)
    assert_equal "PDF was successfully generated.", flash[:notice]
    
    created_pdf = ProcessedPdf.last
    assert_equal @pdf_template, created_pdf.pdf_template
    assert_equal "002", created_pdf.variables_used["invoice_number"]
    assert_equal "Jane Smith", created_pdf.variables_used["customer_name"]
    assert created_pdf.pdf_file.attached?
  end

  test "should handle PDF generation errors" do
    sign_in @user
    
    # Mock Grover to raise an error
    Grover.any_instance.stub(:to_pdf, -> { raise StandardError, "PDF generation failed" }) do
      assert_no_difference("ProcessedPdf.count") do
        post pdf_template_processed_pdfs_url(@pdf_template), params: {
          processed_pdf: {
            metadata: { "source" => "test" }
          },
          variables: {
            "invoice_number" => "003",
            "customer_name" => "Error Test"
          }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_select "div.alert", text: /Error generating PDF: PDF generation failed/
    assert_select "form"  # Should re-render the form
  end

  test "should handle template rendering with variables" do
    sign_in @user
    
    mock_pdf_content = "PDF_CONTENT"
    Grover.any_instance.stub(:to_pdf, mock_pdf_content) do
      post pdf_template_processed_pdfs_url(@pdf_template), params: {
        processed_pdf: {
          metadata: { "source" => "test" }
        },
        variables: {
          "invoice_number" => "INVOICE-123",
          "customer_name" => "Acme Corporation",
          "amount" => "2500.50",
          "due_date" => "2024-03-01"
        }
      }
    end

    created_pdf = ProcessedPdf.last
    expected_html = <<~HTML.strip
      <div class="invoice">
        <h1>Invoice #INVOICE-123</h1>
        <p>Bill to: Acme Corporation</p>
        <p>Amount: $2500.50</p>
        <p>Due: 2024-03-01</p>
      </div>
    HTML
    
    assert_includes created_pdf.original_html, "INVOICE-123"
    assert_includes created_pdf.original_html, "Acme Corporation"
    assert_includes created_pdf.original_html, "2500.50"
    assert_includes created_pdf.original_html, "2024-03-01"
  end

  test "should handle missing variables gracefully" do
    sign_in @user
    
    mock_pdf_content = "PDF_CONTENT"
    Grover.any_instance.stub(:to_pdf, mock_pdf_content) do
      post pdf_template_processed_pdfs_url(@pdf_template), params: {
        processed_pdf: {
          metadata: { "source" => "test" }
        },
        variables: {
          "invoice_number" => "004"
          # Missing other variables
        }
      }
    end

    created_pdf = ProcessedPdf.last
    assert_includes created_pdf.original_html, "004"
    # Missing variables should remain as {{variable_name}}
    assert_includes created_pdf.original_html, "{{customer_name}}"
    assert_includes created_pdf.original_html, "{{amount}}"
  end

  test "should generate filename automatically" do
    sign_in @user
    
    mock_pdf_content = "PDF_CONTENT"
    Grover.any_instance.stub(:to_pdf, mock_pdf_content) do
      post pdf_template_processed_pdfs_url(@pdf_template), params: {
        processed_pdf: {
          metadata: { "source" => "test" }
        },
        variables: {
          "invoice_number" => "AUTO-001",
          "customer_name" => "Auto Test"
        }
      }
    end

    created_pdf = ProcessedPdf.last
    assert created_pdf.filename.present?
    assert created_pdf.filename.ends_with?(".pdf")
    assert_includes created_pdf.filename.downcase, "invoice"
  end

  test "should download processed pdf" do
    # Attach a fake PDF file
    @processed_pdf.pdf_file.attach(
      io: StringIO.new("fake pdf content"),
      filename: "test.pdf",
      content_type: "application/pdf"
    )

    sign_in @user
    get download_pdf_template_processed_pdf_url(@pdf_template, @processed_pdf)
    
    # Should redirect to rails blob path
    assert_response :redirect
    assert_match %r{/rails/active_storage/blobs/}, response.location
  end

  test "should handle download when no file attached" do
    sign_in @user
    
    # Create a processed PDF without attached file
    pdf_without_file = @pdf_template.processed_pdfs.create!(
      filename: "no_file.pdf",
      original_html: "<h1>Test</h1>",
      variables_used: {}
    )

    assert_raises(ActiveStorage::FileNotFoundError) do
      get download_pdf_template_processed_pdf_url(@pdf_template, pdf_without_file)
    end
  end

  test "should not access other user's processed pdfs" do
    other_user = users(:two)
    other_template = PdfTemplate.create!(
      name: "Other Template",
      description: "Template from another user",
      template_content: '<h1>{{title}}</h1>',
      user: other_user,
      active: true
    )
    other_pdf = other_template.processed_pdfs.create!(
      filename: "other.pdf",
      original_html: "<h1>Other</h1>",
      variables_used: {}
    )

    sign_in @user
    
    assert_raises(ActiveRecord::RecordNotFound) do
      get pdf_template_processed_pdf_url(other_template, other_pdf)
    end
  end

  test "should handle complex template with many variables" do
    complex_template = PdfTemplate.create!(
      name: "Complex Template",
      description: "Template with many variables",
      template_content: <<~'HTML',
        <div>
          <h1>{{title}}</h1>
          <div class="content">
            <p>Name: {{name}}</p>
            <p>Email: {{email}}</p>
            <p>Phone: {{phone}}</p>
            <p>Address: {{address}}</p>
            <p>City: {{city}}</p>
            <p>State: {{state}}</p>
            <p>Zip: {{zip}}</p>
            <p>Notes: {{notes}}</p>
          </div>
        </div>
      HTML
      user: @user,
      active: true
    )

    sign_in @user
    get new_pdf_template_processed_pdf_url(complex_template)
    assert_response :success
    
    # Should show form fields for all variables
    %w[title name email phone address city state zip notes].each do |var|
      assert_select "input[name='variables[#{var}]'], textarea[name='variables[#{var}]']"
    end
  end

  test "should preserve HTML structure in generated content" do
    sign_in @user
    
    mock_pdf_content = "PDF_CONTENT"
    Grover.any_instance.stub(:to_pdf, mock_pdf_content) do
      post pdf_template_processed_pdfs_url(@pdf_template), params: {
        processed_pdf: {
          metadata: { "source" => "test" }
        },
        variables: {
          "invoice_number" => "HTML-TEST",
          "customer_name" => "<script>alert('xss')</script>",  # Test XSS protection
          "amount" => "1000.00",
          "due_date" => "2024-04-01"
        }
      }
    end

    created_pdf = ProcessedPdf.last
    # Should escape HTML in variables
    assert_not_includes created_pdf.original_html, "<script>"
    assert_includes created_pdf.original_html, "&lt;script&gt;"
    assert_includes created_pdf.original_html, "HTML-TEST"
  end

  test "should include Tailwind CSS in generated PDF" do
    sign_in @user
    
    generated_html = nil
    Grover.any_instance.stub(:to_pdf) do |html|
      generated_html = html
      "PDF_CONTENT"
    end

    post pdf_template_processed_pdfs_url(@pdf_template), params: {
      processed_pdf: {
        metadata: { "source" => "test" }
      },
      variables: {
        "invoice_number" => "CSS-TEST",
        "customer_name" => "CSS User"
      }
    }

    assert_not_nil generated_html
    assert_includes generated_html, "tailwindcss.com"
    assert_includes generated_html, "<!DOCTYPE html>"
    assert_includes generated_html, "<meta charset=\"utf-8\">"
    assert_includes generated_html, "CSS-TEST"
  end

  test "should handle empty variables hash" do
    sign_in @user
    
    mock_pdf_content = "PDF_CONTENT"
    Grover.any_instance.stub(:to_pdf, mock_pdf_content) do
      post pdf_template_processed_pdfs_url(@pdf_template), params: {
        processed_pdf: {
          metadata: { "source" => "test" }
        }
        # No variables parameter
      }
    end

    created_pdf = ProcessedPdf.last
    assert_equal({}, created_pdf.variables_used)
    # All variables should remain unreplaced
    assert_includes created_pdf.original_html, "{{invoice_number}}"
    assert_includes created_pdf.original_html, "{{customer_name}}"
  end

  test "should validate processed pdf model constraints" do
    sign_in @user
    
    # Test with invalid processed_pdf params (if any validations exist)
    mock_pdf_content = "PDF_CONTENT"
    Grover.any_instance.stub(:to_pdf, mock_pdf_content) do
      post pdf_template_processed_pdfs_url(@pdf_template), params: {
        processed_pdf: {
          metadata: nil  # Test with nil metadata
        },
        variables: {
          "invoice_number" => "VALID-001"
        }
      }
    end

    # Should still create successfully (metadata can be nil)
    assert_redirected_to pdf_template_processed_pdf_url(@pdf_template, ProcessedPdf.last)
  end

  test "should set correct content type for PDF attachment" do
    sign_in @user
    
    mock_pdf_content = "PDF_CONTENT"
    Grover.any_instance.stub(:to_pdf, mock_pdf_content) do
      post pdf_template_processed_pdfs_url(@pdf_template), params: {
        processed_pdf: {
          metadata: { "source" => "test" }
        },
        variables: {
          "invoice_number" => "CT-001"
        }
      }
    end

    created_pdf = ProcessedPdf.last
    assert created_pdf.pdf_file.attached?
    assert_equal "application/pdf", created_pdf.pdf_file.content_type
    assert created_pdf.pdf_file.filename.to_s.ends_with?(".pdf")
  end

  test "should handle network errors during PDF generation" do
    sign_in @user
    
    # Mock network error
    Grover.any_instance.stub(:to_pdf, -> { raise SocketError, "Network error" }) do
      post pdf_template_processed_pdfs_url(@pdf_template), params: {
        processed_pdf: {
          metadata: { "source" => "test" }
        },
        variables: {
          "invoice_number" => "NET-ERROR"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "div.alert", text: /Error generating PDF: Network error/
  end
end