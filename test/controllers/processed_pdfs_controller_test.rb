require "test_helper"

class ProcessedPdfsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = users(:one)
    @pdf_template = pdf_templates(:one)
    @processed_pdf = @pdf_template.processed_pdfs.build(
      original_html: "<div><h1>Invoice #001</h1><p>Bill to: John Doe</p></div>",
      variables_used: { "invoice_number" => "001", "customer_name" => "John Doe" }
    )
    # Attach a dummy PDF file
    @processed_pdf.pdf_file.attach(
      io: StringIO.new("Dummy PDF content"),
      filename: "invoice_001.pdf",
      content_type: "application/pdf"
    )
    @processed_pdf.save!
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
    assert_select "input[name='variables[date]']"
    assert_select "input[name='variables[weather.temperature]']"
    assert_select "input[name='variables[stock.price]']"
  end

  test "should create processed pdf with valid params" do
    sign_in @user
    
    # Mock Grover to avoid actual PDF generation
    mock_pdf_content = "PDF_CONTENT"
    Grover.any_instance.stubs(:to_pdf).returns(mock_pdf_content)
    
    assert_difference("ProcessedPdf.count") do
      post pdf_template_processed_pdfs_url(@pdf_template), params: {
        processed_pdf: {
          metadata: { "source" => "manual", "user" => @user.email }
        },
        variables: {
          "date" => "2024-01-15",
          "weather.temperature" => "20",
          "stock.price" => "150.00"
        }
      }
    end

    assert_redirected_to pdf_template_processed_pdf_path(@pdf_template, ProcessedPdf.last)
    follow_redirect!
    assert_select "div.alert", text: /PDF was successfully generated/
  end

  test "should handle PDF generation errors" do
    sign_in @user
    
    # Mock Grover to raise an error
    Grover.any_instance.stubs(:to_pdf).raises(StandardError, "PDF generation failed")
    
    assert_no_difference("ProcessedPdf.count") do
      post pdf_template_processed_pdfs_url(@pdf_template), params: {
        processed_pdf: {
          metadata: { "source" => "test" }
        },
        variables: {
          "date" => "2024-01-15"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "div.alert", text: /Error generating PDF: PDF generation failed/
    assert_select "form"  # Should re-render the form
  end

  test "should handle template rendering with variables" do
    sign_in @user
    
    mock_pdf_content = "PDF_CONTENT"
    Grover.any_instance.stubs(:to_pdf).returns(mock_pdf_content)
    
    post pdf_template_processed_pdfs_url(@pdf_template), params: {
      processed_pdf: {
        metadata: { "source" => "test" }
      },
      variables: {
        "date" => "2024-01-15",
        "weather.temperature" => "22",
        "stock.price" => "155.50"
      }
    }

    created_pdf = ProcessedPdf.last
    assert_includes created_pdf.original_html, "2024-01-15"
    assert_includes created_pdf.original_html, "22"
    assert_includes created_pdf.original_html, "155.50"
    assert_equal({
      "date" => "2024-01-15",
      "weather.temperature" => "22", 
      "stock.price" => "155.50"
    }, created_pdf.variables_used)
  end

  test "should handle missing variables gracefully" do
    sign_in @user
    
    mock_pdf_content = "PDF_CONTENT"
    Grover.any_instance.stubs(:to_pdf).returns(mock_pdf_content)
    
    post pdf_template_processed_pdfs_url(@pdf_template), params: {
      processed_pdf: {
        metadata: { "source" => "test" }
      },
      variables: {
        "date" => "2024-01-15"
        # Missing other variables
      }
    }

    created_pdf = ProcessedPdf.last
    assert_includes created_pdf.original_html, "2024-01-15"
    # Missing variables should remain as {{variable_name}}
    assert_includes created_pdf.original_html, "{{weather.temperature}}"
    assert_includes created_pdf.original_html, "{{stock.price}}"
  end

  test "should generate filename automatically" do
    sign_in @user
    
    mock_pdf_content = "PDF_CONTENT"
    Grover.any_instance.stubs(:to_pdf).returns(mock_pdf_content)
    
    post pdf_template_processed_pdfs_url(@pdf_template), params: {
      processed_pdf: {
        metadata: { "source" => "test" }
      },
      variables: {
        "date" => "2024-01-15"
      }
    }

    created_pdf = ProcessedPdf.last
    assert created_pdf.filename.present?
    assert created_pdf.filename.ends_with?(".pdf")
    assert_includes created_pdf.filename.downcase, "monthly-report"
  end

  test "should download processed pdf" do
    sign_in @user
    get download_pdf_template_processed_pdf_url(@pdf_template, @processed_pdf)
    
    # Should redirect to blob URL
    assert_response :redirect
    assert @processed_pdf.pdf_file.attached?
  end

  test "should preserve HTML structure in generated content" do
    sign_in @user
    
    mock_pdf_content = "PDF_CONTENT"
    Grover.any_instance.stubs(:to_pdf).returns(mock_pdf_content)
    
    post pdf_template_processed_pdfs_url(@pdf_template), params: {
      processed_pdf: {
        metadata: { "source" => "test" }
      },
      variables: {
        "date" => "2024-01-15",
        "weather.temperature" => "20"
      }
    }

    created_pdf = ProcessedPdf.last
    assert_includes created_pdf.original_html, "<h1>"
    assert_includes created_pdf.original_html, "</h1>"
    assert created_pdf.original_html.html_safe?
  end

  test "should include Tailwind CSS in generated PDF" do
    sign_in @user
    
    generated_html = nil
    Grover.any_instance.expects(:to_pdf).with do |html|
      generated_html = html
      true  # Return true to allow the expectation to pass
    end.returns("PDF_CONTENT")
    
    post pdf_template_processed_pdfs_url(@pdf_template), params: {
      processed_pdf: {
        metadata: { "source" => "test" }
      },
      variables: {
        "date" => "2024-01-15"
      }
    }

    # Check that Tailwind CSS was included
    assert_includes generated_html, "<style"
    assert_match /text-gray-\d+|bg-\w+-\d+|p-\d+|m-\d+/, generated_html
  end

  test "should handle empty variables hash" do
    sign_in @user
    
    mock_pdf_content = "PDF_CONTENT"
    Grover.any_instance.stubs(:to_pdf).returns(mock_pdf_content)
    
    post pdf_template_processed_pdfs_url(@pdf_template), params: {
      processed_pdf: {
        metadata: { "source" => "test" }
      }
      # No variables provided
    }

    created_pdf = ProcessedPdf.last
    # All variables should remain as placeholders
    assert_includes created_pdf.original_html, "{{date}}"
    assert_includes created_pdf.original_html, "{{weather.temperature}}"
  end

  test "should validate processed pdf model constraints" do
    sign_in @user
    
    # Test with invalid processed_pdf params (if any validations exist)
    mock_pdf_content = "PDF_CONTENT"
    Grover.any_instance.stubs(:to_pdf).returns(mock_pdf_content)
    
    post pdf_template_processed_pdfs_url(@pdf_template), params: {
      processed_pdf: {
        # Valid params
        metadata: { "source" => "test" }
      },
      variables: {
        "date" => "2024-01-15"
      }
    }

    assert_response :redirect
    created_pdf = ProcessedPdf.last
    assert created_pdf.persisted?
  end

  test "should set correct content type for PDF attachment" do
    sign_in @user
    
    mock_pdf_content = "PDF_CONTENT"
    Grover.any_instance.stubs(:to_pdf).returns(mock_pdf_content)
    
    post pdf_template_processed_pdfs_url(@pdf_template), params: {
      processed_pdf: {
        metadata: { "source" => "test" }
      },
      variables: {
        "date" => "2024-01-15"
      }
    }

    created_pdf = ProcessedPdf.last
    assert created_pdf.pdf_file.attached?
    assert_equal "application/pdf", created_pdf.pdf_file.content_type
    assert created_pdf.pdf_file.filename.to_s.ends_with?(".pdf")
  end

  test "should handle network errors during PDF generation" do
    sign_in @user
    
    # Mock network error
    Grover.any_instance.stubs(:to_pdf).raises(SocketError, "Network error")
    
    post pdf_template_processed_pdfs_url(@pdf_template), params: {
      processed_pdf: {
        metadata: { "source" => "test" }
      },
      variables: {
        "date" => "2024-01-15"
      }
    }

    assert_response :unprocessable_entity
    assert_select "div.alert", text: /Error generating PDF: Network error/
  end
end