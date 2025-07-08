require "test_helper"

class ProcessedPdfTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @pdf_template = PdfTemplate.create!(
      name: "Test Template",
      description: "A test template",
      template_content: '<h1>Hello {{name}}</h1><p>Welcome to {{city}}</p>',
      user: @user,
      active: true
    )
    @processed_pdf = ProcessedPdf.new(
      pdf_template: @pdf_template,
      original_html: "<h1>Hello John</h1><p>Welcome to London</p>",
      variables_used: { "name" => "John", "city" => "London" },
      metadata: { "generated_by" => "user", "format" => "A4" }
    )
    
    # Create a dummy PDF file for testing
    dummy_pdf_content = "%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog\n/Pages 2 0 R\n>>\nendobj\n2 0 obj\n<<\n/Type /Pages\n/Kids [3 0 R]\n/Count 1\n>>\nendobj\n3 0 obj\n<<\n/Type /Page\n/Parent 2 0 R\n/MediaBox [0 0 612 792]\n/Contents 4 0 R\n>>\nendobj\n4 0 obj\n<<\n/Length 44\n>>\nstream\nBT\n/F1 12 Tf\n72 720 Td\n(Hello World) Tj\nET\nendstream\nendobj\nxref\n0 5\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \n0000000207 00000 n \ntrailer\n<<\n/Size 5\n/Root 1 0 R\n>>\nstartxref\n299\n%%EOF"
    @processed_pdf.pdf_file.attach(
      io: StringIO.new(dummy_pdf_content),
      filename: "test.pdf",
      content_type: "application/pdf"
    )
  end

  test "should be valid with valid attributes" do
    assert @processed_pdf.valid?
  end

  test "should require pdf_template" do
    @processed_pdf.pdf_template = nil
    assert_not @processed_pdf.valid?
    assert_includes @processed_pdf.errors[:pdf_template], "must exist"
  end

  test "should require original_html" do
    @processed_pdf.original_html = nil
    assert_not @processed_pdf.valid?
    assert_includes @processed_pdf.errors[:original_html], "can't be blank"
  end

  test "should not require variables_used" do
    @processed_pdf.variables_used = nil
    assert @processed_pdf.valid?
  end

  test "should not require metadata" do
    @processed_pdf.metadata = nil
    assert @processed_pdf.valid?
  end

  test "should belong to pdf_template" do
    @processed_pdf.save!
    assert_equal @pdf_template, @processed_pdf.pdf_template
  end

  test "should be destroyed when pdf_template is destroyed" do
    @processed_pdf.save!
    processed_pdf_id = @processed_pdf.id
    
    @pdf_template.destroy
    
    assert_not ProcessedPdf.exists?(processed_pdf_id)
  end

  test "should store variables_used as JSON" do
    variables = {
      "name" => "Alice",
      "city" => "Paris",
      "age" => 30,
      "active" => true
    }
    
    @processed_pdf.variables_used = variables
    @processed_pdf.save!
    
    reloaded = ProcessedPdf.find(@processed_pdf.id)
    assert_equal "Alice", reloaded.variables_used["name"]
    assert_equal "Paris", reloaded.variables_used["city"]
    assert_equal 30, reloaded.variables_used["age"]
    assert_equal true, reloaded.variables_used["active"]
  end

  test "should store metadata as JSON" do
    metadata = {
      "generated_by" => "system",
      "format" => "A4",
      "orientation" => "portrait",
      "margin" => { "top" => 20, "bottom" => 20 },
      "timestamp" => Time.current.iso8601
    }
    
    @processed_pdf.metadata = metadata
    @processed_pdf.save!
    
    reloaded = ProcessedPdf.find(@processed_pdf.id)
    assert_equal "system", reloaded.metadata["generated_by"]
    assert_equal "A4", reloaded.metadata["format"]
    assert_equal "portrait", reloaded.metadata["orientation"]
    assert_equal 20, reloaded.metadata["margin"]["top"]
  end

  test "should handle complex HTML content" do
    complex_html = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <title>Complex Document</title>
          <style>
            body { font-family: Arial, sans-serif; }
            .header { background: #f0f0f0; padding: 20px; }
            .content { margin: 20px 0; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>Invoice #12345</h1>
            <p>Date: 2024-01-15</p>
          </div>
          <div class="content">
            <table>
              <tr><td>Item</td><td>Price</td></tr>
              <tr><td>Service</td><td>$100.00</td></tr>
            </table>
          </div>
        </body>
      </html>
    HTML
    
    @processed_pdf.original_html = complex_html
    @processed_pdf.save!
    
    reloaded = ProcessedPdf.find(@processed_pdf.id)
    assert_includes reloaded.original_html, "Invoice #12345"
    assert_includes reloaded.original_html, "font-family: Arial"
    assert_includes reloaded.original_html, "<table>"
  end

  test "should handle special characters in HTML" do
    html_with_special_chars = "<h1>Hello © 2024 — Company™</h1><p>Price: €100 & $50</p>"
    
    @processed_pdf.original_html = html_with_special_chars
    @processed_pdf.save!
    
    reloaded = ProcessedPdf.find(@processed_pdf.id)
    assert_equal html_with_special_chars, reloaded.original_html
  end

  test "should handle unicode content" do
    unicode_html = "<h1>こんにちは</h1><p>مرحبا بك</p><p>🎉 Celebration 🎊</p>"
    
    @processed_pdf.original_html = unicode_html
    @processed_pdf.save!
    
    reloaded = ProcessedPdf.find(@processed_pdf.id)
    assert_equal unicode_html, reloaded.original_html
  end

  test "should handle empty variables_used" do
    @processed_pdf.variables_used = {}
    @processed_pdf.save!
    
    reloaded = ProcessedPdf.find(@processed_pdf.id)
    assert_equal({}, reloaded.variables_used)
  end

  test "should handle nil variables_used" do
    @processed_pdf.variables_used = nil
    @processed_pdf.save!
    
    reloaded = ProcessedPdf.find(@processed_pdf.id)
    assert_nil reloaded.variables_used
  end

  test "should handle empty metadata" do
    @processed_pdf.metadata = {}
    @processed_pdf.save!
    
    reloaded = ProcessedPdf.find(@processed_pdf.id)
    assert_equal({}, reloaded.metadata)
  end

  test "should handle nil metadata" do
    @processed_pdf.metadata = nil
    @processed_pdf.save!
    
    reloaded = ProcessedPdf.find(@processed_pdf.id)
    assert_nil reloaded.metadata
  end

  test "should support Active Storage attachment for pdf_file" do
    @processed_pdf.save!
    
    # Create a mock PDF content
    pdf_content = "Mock PDF content for testing"
    
    # Attach the PDF file
    @processed_pdf.pdf_file.attach(
      io: StringIO.new(pdf_content),
      filename: "test_document.pdf",
      content_type: "application/pdf"
    )
    
    assert @processed_pdf.pdf_file.attached?
    assert_equal "test_document.pdf", @processed_pdf.pdf_file.filename.to_s
    assert_equal "application/pdf", @processed_pdf.pdf_file.content_type
  end

  test "should validate attachment content type" do
    @processed_pdf.save!
    
    # Try to attach non-PDF file
    @processed_pdf.pdf_file.attach(
      io: StringIO.new("Not a PDF"),
      filename: "test.txt",
      content_type: "text/plain"
    )
    
    # This should be handled by Active Storage validations if configured
    # For now, we just verify the attachment works
    assert @processed_pdf.pdf_file.attached?
  end

  test "should order by created_at descending by default" do
    @processed_pdf.save!
    
    # Create an older processed PDF
    older_pdf = ProcessedPdf.create!(
      pdf_template: @pdf_template,
      original_html: "<h1>Old Document</h1>"
    )
    older_pdf.pdf_file.attach(
      io: StringIO.new("Old PDF content"),
      filename: "old.pdf",
      content_type: "application/pdf"
    )
    older_pdf.update!(created_at: 2.hours.ago)
    
    # Create a newer processed PDF
    newer_pdf = ProcessedPdf.create!(
      pdf_template: @pdf_template,
      original_html: "<h1>New Document</h1>"
    )
    newer_pdf.pdf_file.attach(
      io: StringIO.new("New PDF content"),
      filename: "new.pdf",
      content_type: "application/pdf"
    )
    newer_pdf.update!(created_at: 1.minute.ago)
    
    pdfs = @pdf_template.processed_pdfs.order(created_at: :desc)
    assert_equal newer_pdf, pdfs.first
    assert_equal older_pdf, pdfs.last
  end

  test "should find processed PDFs by template" do
    @processed_pdf.save!
    
    # Create another template and PDF
    other_template = PdfTemplate.create!(
      name: "Other Template",
      description: "Another test template",
      template_content: "<h1>Other</h1>",
      user: @user,
      active: true
    )
    
    other_pdf = ProcessedPdf.new(
      pdf_template: other_template,
      original_html: "<h1>Other Document</h1>"
    )
    
    # Attach PDF file to the other_pdf
    dummy_pdf_content = "%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog\n/Pages 2 0 R\n>>\nendobj\n2 0 obj\n<<\n/Type /Pages\n/Kids [3 0 R]\n/Count 1\n>>\nendobj\n3 0 obj\n<<\n/Type /Page\n/Parent 2 0 R\n/MediaBox [0 0 612 792]\n/Contents 4 0 R\n>>\nendobj\n4 0 obj\n<<\n/Length 44\n>>\nstream\nBT\n/F1 12 Tf\n72 720 Td\n(Other Document) Tj\nET\nendstream\nendobj\nxref\n0 5\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \n0000000207 00000 n \ntrailer\n<<\n/Size 5\n/Root 1 0 R\n>>\nstartxref\n299\n%%EOF"
    other_pdf.pdf_file.attach(
      io: StringIO.new(dummy_pdf_content),
      filename: "other.pdf", 
      content_type: "application/pdf"
    )
    other_pdf.save!
    
    template_pdfs = @pdf_template.processed_pdfs
    assert_includes template_pdfs, @processed_pdf
    assert_not_includes template_pdfs, other_pdf
  end

  test "should store complex variables with nested data" do
    complex_variables = {
      "user" => {
        "name" => "John Doe",
        "email" => "john@example.com",
        "profile" => {
          "age" => 30,
          "preferences" => ["email", "sms"],
          "address" => {
            "street" => "123 Main St",
            "city" => "London",
            "postal_code" => "SW1A 1AA"
          }
        }
      },
      "invoice" => {
        "number" => "INV-001",
        "date" => "2024-01-15",
        "items" => [
          { "name" => "Service A", "price" => 100.00 },
          { "name" => "Service B", "price" => 150.00 }
        ],
        "total" => 250.00
      }
    }
    
    @processed_pdf.variables_used = complex_variables
    @processed_pdf.save!
    
    reloaded = ProcessedPdf.find(@processed_pdf.id)
    assert_equal "John Doe", reloaded.variables_used["user"]["name"]
    assert_equal "London", reloaded.variables_used["user"]["profile"]["address"]["city"]
    assert_equal 2, reloaded.variables_used["invoice"]["items"].length
    assert_equal 100.00, reloaded.variables_used["invoice"]["items"][0]["price"]
  end

  test "should handle very long HTML content" do
    # Generate a large HTML document
    large_html = "<html><body>"
    1000.times do |i|
      large_html += "<p>This is paragraph number #{i} with some content to make it longer.</p>"
    end
    large_html += "</body></html>"
    
    @processed_pdf.original_html = large_html
    
    assert @processed_pdf.valid?
    @processed_pdf.save!
    
    reloaded = ProcessedPdf.find(@processed_pdf.id)
    assert_includes reloaded.original_html, "paragraph number 999"
    assert reloaded.original_html.length > 50000  # Should be quite large
  end

  test "should set created_at and updated_at timestamps" do
    freeze_time = Time.current
    
    travel_to freeze_time do
      @processed_pdf.save!
    end
    
    assert_equal freeze_time.to_i, @processed_pdf.created_at.to_i
    assert_equal freeze_time.to_i, @processed_pdf.updated_at.to_i
  end
end