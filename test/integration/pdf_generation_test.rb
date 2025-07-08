require "test_helper"

class PdfGenerationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  
  setup do
    @user = users(:one)
    @template = @user.pdf_templates.create!(
      name: "Test Invoice",
      template_content: <<~'HTML',
        <h1>Invoice #{{invoice_number}}</h1>
        <p>Customer: {{customer_name}}</p>
        <p>Total: ${{total}}</p>
      HTML
    )
    # Disable any template data sources to prevent dynamic data fetching
    @template.template_data_sources.update_all(enabled: false)
  end

  test "should generate PDF with Grover" do
    sign_in @user
    
    post pdf_template_processed_pdfs_path(@template), params: {
      processed_pdf: {
        metadata: {}
      },
      variables: {
        invoice_number: "INV-001",
        customer_name: "John Doe",
        total: "100.00"
      }
    }
    
    assert_response :redirect
    processed_pdf = ProcessedPdf.last
    
    assert_not_nil processed_pdf
    assert_equal @template, processed_pdf.pdf_template
    assert_includes processed_pdf.original_html, "Invoice #INV-001"
    assert_includes processed_pdf.original_html, "Customer: John Doe"
    assert_includes processed_pdf.original_html, "Total: $100.00"
    
    # Check that PDF file is attached
    assert processed_pdf.pdf_file.attached?
  end

  test "should handle PDF generation errors gracefully" do
    # Mock Grover to raise an error
    Grover.any_instance.stubs(:to_pdf).raises(StandardError.new("Chrome crashed"))
    
    sign_in @user
    
    post pdf_template_processed_pdfs_path(@template), params: {
      processed_pdf: {
        metadata: {}
      },
      variables: { invoice_number: "INV-001" }
    }
    
    assert_response :unprocessable_entity
    assert_match /Chrome crashed/, flash[:alert]
  end
end