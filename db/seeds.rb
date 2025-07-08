# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding database..."

# Create sample PDF templates
invoice_template = PdfTemplate.find_or_create_by!(name: "Invoice Template") do |template|
  template.description = "A professional invoice template with company branding"
  template.template_content = <<~HTML
    <div class="invoice-container">
      <div class="header">
        <h1 class="text-3xl font-bold text-gray-800">INVOICE</h1>
        <div class="text-right text-gray-600">
          <p>Invoice #: {{invoice_number}}</p>
          <p>Date: {{invoice_date}}</p>
          <p>Due Date: {{due_date}}</p>
        </div>
      </div>
      
      <div class="mt-8 grid grid-cols-2 gap-8">
        <div>
          <h3 class="font-semibold text-gray-700">From:</h3>
          <p class="mt-2">{{company_name}}</p>
          <p>{{company_address}}</p>
          <p>{{company_email}}</p>
        </div>
        
        <div>
          <h3 class="font-semibold text-gray-700">Bill To:</h3>
          <p class="mt-2">{{customer_name}}</p>
          <p>{{customer_address}}</p>
          <p>{{customer_email}}</p>
        </div>
      </div>
      
      <table class="w-full mt-8">
        <thead>
          <tr class="border-b-2 border-gray-300">
            <th class="text-left py-2">Description</th>
            <th class="text-right py-2">Quantity</th>
            <th class="text-right py-2">Price</th>
            <th class="text-right py-2">Total</th>
          </tr>
        </thead>
        <tbody>
          <tr class="border-b border-gray-200">
            <td class="py-2">{{item_description}}</td>
            <td class="text-right py-2">{{item_quantity}}</td>
            <td class="text-right py-2">{{item_price}}</td>
            <td class="text-right py-2">{{item_total}}</td>
          </tr>
        </tbody>
      </table>
      
      <div class="mt-8 text-right">
        <p class="text-lg font-semibold">Total: {{total_amount}}</p>
      </div>
      
      <div class="mt-12 text-center text-gray-600 text-sm">
        <p>Thank you for your business!</p>
      </div>
    </div>
  HTML
  template.active = true
end

letter_template = PdfTemplate.find_or_create_by!(name: "Business Letter") do |template|
  template.description = "A formal business letter template"
  template.template_content = <<~HTML
    <div class="letter-container">
      <div class="mb-8">
        <p>{{sender_name}}</p>
        <p>{{sender_address}}</p>
        <p>{{sender_city}}</p>
        <p class="mt-4">{{date}}</p>
      </div>
      
      <div class="mb-8">
        <p>{{recipient_name}}</p>
        <p>{{recipient_title}}</p>
        <p>{{recipient_company}}</p>
        <p>{{recipient_address}}</p>
      </div>
      
      <div class="mb-4">
        <p>Dear {{recipient_name}},</p>
      </div>
      
      <div class="space-y-4">
        <p>{{paragraph_1}}</p>
        <p>{{paragraph_2}}</p>
        <p>{{paragraph_3}}</p>
      </div>
      
      <div class="mt-8">
        <p>{{closing}},</p>
        <div class="mt-12">
          <p>{{sender_name}}</p>
          <p>{{sender_title}}</p>
        </div>
      </div>
    </div>
  HTML
  template.active = true
end

certificate_template = PdfTemplate.find_or_create_by!(name: "Certificate of Achievement") do |template|
  template.description = "An elegant certificate template for achievements and awards"
  template.template_content = <<~HTML
    <div class="certificate-container text-center p-12" style="border: 3px solid #d4af37;">
      <div class="mb-8">
        <h1 class="text-4xl font-serif text-gray-800">Certificate of Achievement</h1>
        <div class="mt-2 mx-auto w-32 border-b-2 border-gold-500"></div>
      </div>
      
      <div class="mb-8">
        <p class="text-lg text-gray-600">This is to certify that</p>
        <h2 class="text-3xl font-bold text-gray-800 mt-4">{{recipient_name}}</h2>
      </div>
      
      <div class="mb-8">
        <p class="text-lg text-gray-600">has successfully completed</p>
        <h3 class="text-2xl font-semibold text-gray-800 mt-4">{{achievement_title}}</h3>
      </div>
      
      <div class="mb-12">
        <p class="text-gray-600">{{achievement_description}}</p>
      </div>
      
      <div class="flex justify-between items-end mt-16">
        <div class="text-center">
          <div class="border-t-2 border-gray-400 pt-2 px-8">
            <p class="text-sm text-gray-600">Date</p>
            <p class="font-medium">{{date}}</p>
          </div>
        </div>
        
        <div class="text-center">
          <div class="border-t-2 border-gray-400 pt-2 px-8">
            <p class="text-sm text-gray-600">Authorized Signature</p>
            <p class="font-medium">{{authorized_by}}</p>
          </div>
        </div>
      </div>
    </div>
  HTML
  template.active = true
end

report_template = PdfTemplate.find_or_create_by!(name: "Simple Report") do |template|
  template.description = "A clean report template without variables"
  template.template_content = <<~HTML
    <div class="report-container">
      <header class="mb-8">
        <h1 class="text-3xl font-bold text-center text-gray-800">Monthly Sales Report</h1>
        <p class="text-center text-gray-600 mt-2">January 2024</p>
      </header>
      
      <section class="mb-8">
        <h2 class="text-2xl font-semibold mb-4">Executive Summary</h2>
        <p class="text-gray-700 leading-relaxed">
          This report provides a comprehensive overview of our sales performance for January 2024. 
          Overall, we saw a 15% increase in revenue compared to the previous month, with particularly 
          strong performance in the digital products category.
        </p>
      </section>
      
      <section class="mb-8">
        <h2 class="text-2xl font-semibold mb-4">Key Metrics</h2>
        <div class="grid grid-cols-3 gap-4">
          <div class="bg-blue-50 p-4 rounded">
            <h3 class="font-semibold text-blue-800">Total Revenue</h3>
            <p class="text-2xl font-bold text-blue-900">$125,000</p>
          </div>
          <div class="bg-green-50 p-4 rounded">
            <h3 class="font-semibold text-green-800">New Customers</h3>
            <p class="text-2xl font-bold text-green-900">342</p>
          </div>
          <div class="bg-purple-50 p-4 rounded">
            <h3 class="font-semibold text-purple-800">Conversion Rate</h3>
            <p class="text-2xl font-bold text-purple-900">3.2%</p>
          </div>
        </div>
      </section>
      
      <section>
        <h2 class="text-2xl font-semibold mb-4">Recommendations</h2>
        <ul class="list-disc list-inside space-y-2 text-gray-700">
          <li>Continue to invest in digital marketing campaigns</li>
          <li>Expand product offerings in the top-performing categories</li>
          <li>Improve customer retention through enhanced support services</li>
        </ul>
      </section>
    </div>
  HTML
  template.active = true
end

puts "Created #{PdfTemplate.count} PDF templates"

# Create some sample processed PDFs for the invoice template
if Rails.env.development?
  3.times do |i|
    processed_pdf = invoice_template.processed_pdfs.build(
      original_html: invoice_template.render_with_variables({
        invoice_number: "INV-#{1000 + i}",
        invoice_date: Date.today.strftime("%B %d, %Y"),
        due_date: (Date.today + 30).strftime("%B %d, %Y"),
        company_name: "Acme Corp",
        company_address: "123 Business St, Suite 100",
        company_email: "billing@acmecorp.com",
        customer_name: "Customer #{i + 1}",
        customer_address: "456 Client Ave",
        customer_email: "customer#{i + 1}@example.com",
        item_description: "Professional Services",
        item_quantity: "#{10 + i * 5}",
        item_price: "$100.00",
        item_total: "$#{(10 + i * 5) * 100}.00",
        total_amount: "$#{(10 + i * 5) * 100}.00"
      }),
      variables_used: {
        invoice_number: "INV-#{1000 + i}",
        customer_name: "Customer #{i + 1}"
      },
      metadata: {
        generated_by: "seeds.rb",
        environment: Rails.env
      }
    )
    
    # Simulate PDF attachment (in real app, Grover would generate this)
    processed_pdf.pdf_file.attach(
      io: StringIO.new("Sample PDF content for invoice #{i + 1}"),
      filename: "invoice_#{1000 + i}.pdf",
      content_type: "application/pdf"
    )
    
    processed_pdf.save!
  end
  
  puts "Created #{ProcessedPdf.count} sample processed PDFs"
end

puts "Database seeding completed!"AdminUser.create!(email: 'admin@example.com', password: 'password', password_confirmation: 'password') if Rails.env.development?