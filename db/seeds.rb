# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding database..."

# Create admin user
AdminUser.find_or_create_by!(email: 'admin@example.com') do |admin|
  admin.password = 'password'
  admin.password_confirmation = 'password'
end if Rails.env.development?

# Create regular user
user = User.find_or_create_by!(email: 'user@example.com') do |u|
  u.password = 'password'
  u.password_confirmation = 'password'
end

puts "Created users"

# Create sample PDF templates
invoice_template = PdfTemplate.find_or_create_by!(name: "Invoice Template", user: user) do |template|
  template.description = "A professional invoice template with company branding"
  template.template_content = <<~'HTML'
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

letter_template = PdfTemplate.find_or_create_by!(name: "Business Letter", user: user) do |template|
  template.description = "A formal business letter template"
  template.template_content = <<~'HTML'
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

certificate_template = PdfTemplate.find_or_create_by!(name: "Certificate of Achievement", user: user) do |template|
  template.description = "An elegant certificate template for achievements and awards"
  template.template_content = <<~'HTML'
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

report_template = PdfTemplate.find_or_create_by!(name: "Simple Report", user: user) do |template|
  template.description = "A clean report template without variables"
  template.template_content = <<~'HTML'
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

# Create more diverse template examples
meeting_minutes = PdfTemplate.find_or_create_by!(name: "Meeting Minutes", user: user) do |template|
  template.description = "Professional meeting minutes template"
  template.template_content = <<~'HTML'
    <div class="meeting-minutes max-w-4xl mx-auto p-8">
      <header class="border-b-2 border-gray-300 pb-6 mb-6">
        <h1 class="text-3xl font-bold text-gray-800">Meeting Minutes</h1>
        <div class="mt-4 grid grid-cols-2 gap-4 text-sm">
          <div>
            <strong>Meeting:</strong> {{meeting_title}}<br>
            <strong>Date:</strong> {{meeting_date}}<br>
            <strong>Time:</strong> {{meeting_time}}
          </div>
          <div>
            <strong>Location:</strong> {{meeting_location}}<br>
            <strong>Chair:</strong> {{meeting_chair}}<br>
            <strong>Secretary:</strong> {{meeting_secretary}}
          </div>
        </div>
      </header>
      
      <section class="mb-6">
        <h2 class="text-xl font-semibold mb-3 text-gray-700">Attendees</h2>
        <div class="bg-gray-50 p-4 rounded">
          {{attendees_list}}
        </div>
      </section>
      
      <section class="mb-6">
        <h2 class="text-xl font-semibold mb-3 text-gray-700">Agenda Items</h2>
        <div class="space-y-4">
          {{agenda_items}}
        </div>
      </section>
      
      <section class="mb-6">
        <h2 class="text-xl font-semibold mb-3 text-gray-700">Action Items</h2>
        <table class="w-full border border-gray-300">
          <thead class="bg-gray-100">
            <tr>
              <th class="border border-gray-300 p-2 text-left">Action</th>
              <th class="border border-gray-300 p-2 text-left">Responsible</th>
              <th class="border border-gray-300 p-2 text-left">Due Date</th>
            </tr>
          </thead>
          <tbody>
            {{action_items_table}}
          </tbody>
        </table>
      </section>
      
      <section>
        <h2 class="text-xl font-semibold mb-3 text-gray-700">Next Meeting</h2>
        <p><strong>Date:</strong> {{next_meeting_date}}</p>
        <p><strong>Location:</strong> {{next_meeting_location}}</p>
      </section>
    </div>
  HTML
  template.active = true
end

project_proposal = PdfTemplate.find_or_create_by!(name: "Project Proposal", user: user) do |template|
  template.description = "Comprehensive project proposal template"
  template.template_content = <<~'HTML'
    <div class="proposal max-w-4xl mx-auto p-8">
      <div class="cover-page text-center mb-12">
        <h1 class="text-4xl font-bold text-blue-800 mb-4">{{project_title}}</h1>
        <h2 class="text-2xl text-gray-600 mb-8">Project Proposal</h2>
        <div class="border-t-2 border-b-2 border-blue-200 py-6 my-8">
          <p class="text-lg">Prepared for: <strong>{{client_name}}</strong></p>
          <p class="text-lg">Prepared by: <strong>{{company_name}}</strong></p>
          <p class="text-lg">Date: <strong>{{proposal_date}}</strong></p>
        </div>
      </div>
      
      <section class="mb-8">
        <h2 class="text-2xl font-semibold text-blue-800 mb-4">Executive Summary</h2>
        <div class="bg-blue-50 p-6 rounded-lg">
          <p class="text-gray-700 leading-relaxed">{{executive_summary}}</p>
        </div>
      </section>
      
      <section class="mb-8">
        <h2 class="text-2xl font-semibold text-blue-800 mb-4">Project Scope</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <h3 class="text-lg font-semibold mb-2">Objectives</h3>
            <ul class="list-disc list-inside space-y-1 text-gray-700">
              {{project_objectives}}
            </ul>
          </div>
          <div>
            <h3 class="text-lg font-semibold mb-2">Deliverables</h3>
            <ul class="list-disc list-inside space-y-1 text-gray-700">
              {{project_deliverables}}
            </ul>
          </div>
        </div>
      </section>
      
      <section class="mb-8">
        <h2 class="text-2xl font-semibold text-blue-800 mb-4">Timeline & Budget</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="bg-green-50 p-4 rounded">
            <h3 class="text-lg font-semibold text-green-800">Project Duration</h3>
            <p class="text-2xl font-bold text-green-900">{{project_duration}}</p>
          </div>
          <div class="bg-blue-50 p-4 rounded">
            <h3 class="text-lg font-semibold text-blue-800">Total Investment</h3>
            <p class="text-2xl font-bold text-blue-900">{{total_budget}}</p>
          </div>
        </div>
      </section>
      
      <section class="mb-8">
        <h2 class="text-2xl font-semibold text-blue-800 mb-4">Team</h2>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          {{team_members}}
        </div>
      </section>
      
      <section>
        <h2 class="text-2xl font-semibold text-blue-800 mb-4">Next Steps</h2>
        <ol class="list-decimal list-inside space-y-2 text-gray-700">
          {{next_steps}}
        </ol>
      </section>
    </div>
  HTML
  template.active = true
end

financial_report = PdfTemplate.find_or_create_by!(name: "Financial Report", user: user) do |template|
  template.description = "Quarterly financial report with dynamic stock data"
  template.template_content = <<~'HTML'
    <div class="financial-report max-w-4xl mx-auto p-8">
      <header class="text-center mb-8 border-b-2 border-indigo-200 pb-6">
        <h1 class="text-3xl font-bold text-indigo-800">{{company_name}}</h1>
        <h2 class="text-xl text-gray-600 mt-2">Quarterly Financial Report</h2>
        <p class="text-lg text-gray-500 mt-2">{{report_period}}</p>
      </header>
      
      <section class="mb-8">
        <h2 class="text-2xl font-semibold text-indigo-800 mb-4">Market Performance</h2>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <div class="bg-indigo-50 p-4 rounded-lg text-center">
            <h3 class="font-semibold text-indigo-800">Stock Price</h3>
            <p class="text-2xl font-bold text-indigo-900">${{stocks.price}}</p>
            <p class="text-sm text-indigo-600">{{stocks.change_percent}} change</p>
          </div>
          <div class="bg-green-50 p-4 rounded-lg text-center">
            <h3 class="font-semibold text-green-800">Volume</h3>
            <p class="text-2xl font-bold text-green-900">{{stocks.volume}}</p>
            <p class="text-sm text-green-600">Shares traded</p>
          </div>
          <div class="bg-blue-50 p-4 rounded-lg text-center">
            <h3 class="font-semibold text-blue-800">Previous Close</h3>
            <p class="text-2xl font-bold text-blue-900">${{stocks.previous_close}}</p>
            <p class="text-sm text-blue-600">Last session</p>
          </div>
        </div>
      </section>
      
      <section class="mb-8">
        <h2 class="text-2xl font-semibold text-indigo-800 mb-4">Financial Highlights</h2>
        <table class="w-full border border-gray-300">
          <thead class="bg-gray-100">
            <tr>
              <th class="border border-gray-300 p-3 text-left">Metric</th>
              <th class="border border-gray-300 p-3 text-right">Current Quarter</th>
              <th class="border border-gray-300 p-3 text-right">Previous Quarter</th>
              <th class="border border-gray-300 p-3 text-right">Change</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td class="border border-gray-300 p-3 font-semibold">Revenue</td>
              <td class="border border-gray-300 p-3 text-right">{{current_revenue}}</td>
              <td class="border border-gray-300 p-3 text-right">{{previous_revenue}}</td>
              <td class="border border-gray-300 p-3 text-right">{{revenue_change}}</td>
            </tr>
            <tr class="bg-gray-50">
              <td class="border border-gray-300 p-3 font-semibold">Net Income</td>
              <td class="border border-gray-300 p-3 text-right">{{current_income}}</td>
              <td class="border border-gray-300 p-3 text-right">{{previous_income}}</td>
              <td class="border border-gray-300 p-3 text-right">{{income_change}}</td>
            </tr>
            <tr>
              <td class="border border-gray-300 p-3 font-semibold">EPS</td>
              <td class="border border-gray-300 p-3 text-right">{{current_eps}}</td>
              <td class="border border-gray-300 p-3 text-right">{{previous_eps}}</td>
              <td class="border border-gray-300 p-3 text-right">{{eps_change}}</td>
            </tr>
          </tbody>
        </table>
      </section>
      
      <section class="mb-8">
        <h2 class="text-2xl font-semibold text-indigo-800 mb-4">Key Metrics</h2>
        <div class="bg-gray-50 p-6 rounded-lg">
          <p class="text-gray-700 leading-relaxed mb-4">{{executive_commentary}}</p>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <h3 class="font-semibold mb-2">Strengths</h3>
              <ul class="list-disc list-inside text-sm text-gray-600">
                {{strengths_list}}
              </ul>
            </div>
            <div>
              <h3 class="font-semibold mb-2">Challenges</h3>
              <ul class="list-disc list-inside text-sm text-gray-600">
                {{challenges_list}}
              </ul>
            </div>
          </div>
        </div>
      </section>
      
      <footer class="text-center text-sm text-gray-500 mt-12 pt-6 border-t border-gray-300">
        <p>Report generated on {{generation_date}} | Data as of {{data_date}}</p>
      </footer>
    </div>
  HTML
  template.active = true
end

event_invitation = PdfTemplate.find_or_create_by!(name: "Event Invitation", user: user) do |template|
  template.description = "Elegant event invitation template"
  template.template_content = <<~'HTML'
    <div class="invitation max-w-2xl mx-auto p-8 bg-gradient-to-br from-purple-50 to-pink-50">
      <div class="text-center border-4 border-purple-200 p-8 rounded-lg bg-white shadow-lg">
        <div class="mb-6">
          <h1 class="text-4xl font-elegant text-purple-800 mb-2">{{event_title}}</h1>
          <div class="w-24 h-1 bg-purple-400 mx-auto rounded"></div>
        </div>
        
        <div class="mb-8">
          <p class="text-lg text-gray-700 italic">{{event_subtitle}}</p>
        </div>
        
        <div class="space-y-4 mb-8">
          <div class="flex items-center justify-center space-x-2">
            <span class="text-purple-600 font-semibold">📅</span>
            <span class="text-gray-700">{{event_date}}</span>
          </div>
          
          <div class="flex items-center justify-center space-x-2">
            <span class="text-purple-600 font-semibold">🕒</span>
            <span class="text-gray-700">{{event_time}}</span>
          </div>
          
          <div class="flex items-center justify-center space-x-2">
            <span class="text-purple-600 font-semibold">📍</span>
            <span class="text-gray-700">{{event_location}}</span>
          </div>
        </div>
        
        <div class="bg-purple-50 p-6 rounded-lg mb-6">
          <h3 class="font-semibold text-purple-800 mb-2">Event Details</h3>
          <p class="text-gray-700 text-sm leading-relaxed">{{event_description}}</p>
        </div>
        
        <div class="bg-pink-50 p-4 rounded-lg mb-6">
          <h3 class="font-semibold text-pink-800 mb-2">Dress Code</h3>
          <p class="text-gray-700 text-sm">{{dress_code}}</p>
        </div>
        
        <div class="border-t border-purple-200 pt-6">
          <p class="text-sm text-gray-600 mb-2">RSVP by {{rsvp_date}}</p>
          <p class="text-sm text-gray-600">Contact: {{contact_info}}</p>
        </div>
        
        <div class="mt-6">
          <p class="text-lg font-semibold text-purple-800">{{host_name}}</p>
          <p class="text-sm text-gray-600">cordially invites you</p>
        </div>
      </div>
    </div>
  HTML
  template.active = true
end

product_spec = PdfTemplate.find_or_create_by!(name: "Product Specification", user: user) do |template|
  template.description = "Technical product specification document"
  template.template_content = <<~'HTML'
    <div class="product-spec max-w-4xl mx-auto p-8">
      <header class="mb-8">
        <div class="flex items-center justify-between border-b-2 border-blue-200 pb-4">
          <div>
            <h1 class="text-3xl font-bold text-blue-800">{{product_name}}</h1>
            <p class="text-lg text-gray-600">Product Specification Document</p>
          </div>
          <div class="text-right text-sm text-gray-500">
            <p>Version: {{spec_version}}</p>
            <p>Date: {{spec_date}}</p>
          </div>
        </div>
      </header>
      
      <section class="mb-8">
        <h2 class="text-2xl font-semibold text-blue-800 mb-4">Overview</h2>
        <div class="bg-blue-50 p-6 rounded-lg">
          <p class="text-gray-700 leading-relaxed mb-4">{{product_overview}}</p>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <h3 class="font-semibold text-blue-700 mb-2">Product Category</h3>
              <p class="text-gray-600">{{product_category}}</p>
            </div>
            <div>
              <h3 class="font-semibold text-blue-700 mb-2">Target Market</h3>
              <p class="text-gray-600">{{target_market}}</p>
            </div>
          </div>
        </div>
      </section>
      
      <section class="mb-8">
        <h2 class="text-2xl font-semibold text-blue-800 mb-4">Technical Specifications</h2>
        <table class="w-full border border-gray-300">
          <thead class="bg-gray-100">
            <tr>
              <th class="border border-gray-300 p-3 text-left">Specification</th>
              <th class="border border-gray-300 p-3 text-left">Value</th>
              <th class="border border-gray-300 p-3 text-left">Unit</th>
            </tr>
          </thead>
          <tbody>
            {{technical_specs_table}}
          </tbody>
        </table>
      </section>
      
      <section class="mb-8">
        <h2 class="text-2xl font-semibold text-blue-800 mb-4">Features</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <h3 class="text-lg font-semibold text-green-800 mb-3">Core Features</h3>
            <ul class="list-disc list-inside space-y-2 text-gray-700">
              {{core_features}}
            </ul>
          </div>
          <div>
            <h3 class="text-lg font-semibold text-orange-800 mb-3">Advanced Features</h3>
            <ul class="list-disc list-inside space-y-2 text-gray-700">
              {{advanced_features}}
            </ul>
          </div>
        </div>
      </section>
      
      <section class="mb-8">
        <h2 class="text-2xl font-semibold text-blue-800 mb-4">Performance Requirements</h2>
        <div class="bg-yellow-50 p-6 rounded-lg">
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="text-center">
              <h3 class="font-semibold text-yellow-800">Response Time</h3>
              <p class="text-2xl font-bold text-yellow-900">{{response_time}}</p>
            </div>
            <div class="text-center">
              <h3 class="font-semibold text-yellow-800">Throughput</h3>
              <p class="text-2xl font-bold text-yellow-900">{{throughput}}</p>
            </div>
            <div class="text-center">
              <h3 class="font-semibold text-yellow-800">Uptime</h3>
              <p class="text-2xl font-bold text-yellow-900">{{uptime_requirement}}</p>
            </div>
          </div>
        </div>
      </section>
      
      <section class="mb-8">
        <h2 class="text-2xl font-semibold text-blue-800 mb-4">Dependencies & Requirements</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <h3 class="text-lg font-semibold mb-3">System Requirements</h3>
            <div class="bg-gray-50 p-4 rounded">
              {{system_requirements}}
            </div>
          </div>
          <div>
            <h3 class="text-lg font-semibold mb-3">Dependencies</h3>
            <div class="bg-gray-50 p-4 rounded">
              {{dependencies_list}}
            </div>
          </div>
        </div>
      </section>
      
      <section>
        <h2 class="text-2xl font-semibold text-blue-800 mb-4">Implementation Notes</h2>
        <div class="bg-red-50 p-6 rounded-lg border-l-4 border-red-400">
          <h3 class="font-semibold text-red-800 mb-2">Important Considerations</h3>
          <p class="text-gray-700 text-sm leading-relaxed">{{implementation_notes}}</p>
        </div>
      </section>
      
      <footer class="mt-12 pt-6 border-t border-gray-300 text-center text-sm text-gray-500">
        <p>Document prepared by: {{prepared_by}} | Approved by: {{approved_by}}</p>
      </footer>
    </div>
  HTML
  template.active = true
end

news_newsletter = PdfTemplate.find_or_create_by!(name: "News Newsletter", user: user) do |template|
  template.description = "Dynamic newsletter template with live news integration"
  template.template_content = <<~'HTML'
    <div class="newsletter max-w-4xl mx-auto p-8">
      <header class="text-center mb-8 border-b-4 border-red-600 pb-6">
        <h1 class="text-4xl font-bold text-red-800">{{newsletter_title}}</h1>
        <p class="text-lg text-gray-600 mt-2">{{publication_date}} | Issue #{{issue_number}}</p>
        <p class="text-sm text-gray-500">{{subscriber_count}} subscribers</p>
      </header>
      
      <section class="mb-8">
        <h2 class="text-2xl font-bold text-red-700 mb-4 border-l-4 border-red-500 pl-4">Top Headlines</h2>
        <div class="grid grid-cols-1 gap-6">
          {{top_headlines}}
        </div>
      </section>
      
      <section class="mb-8">
        <h2 class="text-2xl font-bold text-blue-700 mb-4 border-l-4 border-blue-500 pl-4">Technology News</h2>
        <div class="bg-blue-50 p-6 rounded-lg">
          {{tech_news_section}}
        </div>
      </section>
      
      <section class="mb-8">
        <h2 class="text-2xl font-bold text-green-700 mb-4 border-l-4 border-green-500 pl-4">Business Updates</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          {{business_news}}
        </div>
      </section>
      
      <section class="mb-8">
        <h2 class="text-2xl font-bold text-purple-700 mb-4 border-l-4 border-purple-500 pl-4">Weather Outlook</h2>
        <div class="bg-purple-50 p-6 rounded-lg">
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="text-center">
              <h3 class="font-semibold text-purple-800">Current Temperature</h3>
              <p class="text-3xl font-bold text-purple-900">{{weather.temperature}}°C</p>
              <p class="text-sm text-purple-600">{{weather.condition}}</p>
            </div>
            <div class="text-center">
              <h3 class="font-semibold text-purple-800">Humidity</h3>
              <p class="text-3xl font-bold text-purple-900">{{weather.humidity}}%</p>
              <p class="text-sm text-purple-600">Current levels</p>
            </div>
            <div class="text-center">
              <h3 class="font-semibold text-purple-800">Location</h3>
              <p class="text-lg font-bold text-purple-900">{{weather.location}}</p>
              <p class="text-sm text-purple-600">{{weather.timezone}}</p>
            </div>
          </div>
        </div>
      </section>
      
      <section class="mb-8">
        <h2 class="text-2xl font-bold text-orange-700 mb-4 border-l-4 border-orange-500 pl-4">Editor's Pick</h2>
        <div class="bg-orange-50 p-6 rounded-lg border-l-4 border-orange-400">
          <h3 class="text-xl font-semibold text-orange-800 mb-3">{{editors_pick_title}}</h3>
          <p class="text-gray-700 leading-relaxed mb-4">{{editors_pick_content}}</p>
          <p class="text-sm text-orange-600 italic">- {{editor_name}}, Editor-in-Chief</p>
        </div>
      </section>
      
      <section class="mb-8">
        <h2 class="text-2xl font-bold text-gray-700 mb-4 border-l-4 border-gray-500 pl-4">Quick Stats</h2>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div class="bg-gray-100 p-4 rounded text-center">
            <h3 class="font-semibold text-gray-700">Articles</h3>
            <p class="text-2xl font-bold text-gray-900">{{article_count}}</p>
          </div>
          <div class="bg-gray-100 p-4 rounded text-center">
            <h3 class="font-semibold text-gray-700">Sources</h3>
            <p class="text-2xl font-bold text-gray-900">{{source_count}}</p>
          </div>
          <div class="bg-gray-100 p-4 rounded text-center">
            <h3 class="font-semibold text-gray-700">Countries</h3>
            <p class="text-2xl font-bold text-gray-900">{{country_count}}</p>
          </div>
          <div class="bg-gray-100 p-4 rounded text-center">
            <h3 class="font-semibold text-gray-700">Languages</h3>
            <p class="text-2xl font-bold text-gray-900">{{language_count}}</p>
          </div>
        </div>
      </section>
      
      <footer class="text-center border-t-2 border-gray-300 pt-6 mt-8">
        <p class="text-lg font-semibold text-gray-800">{{newsletter_title}}</p>
        <p class="text-sm text-gray-600 mt-2">Published by {{publisher_name}} | {{contact_email}}</p>
        <p class="text-xs text-gray-500 mt-2">You received this newsletter because you subscribed to our updates.</p>
        <div class="mt-4 text-xs text-gray-400">
          <p>Data sources: {{data_sources_attribution}}</p>
          <p>Newsletter generated on {{generation_timestamp}}</p>
        </div>
      </footer>
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

puts "Database seeding completed!"

# Create data sources for the user
weather_source = user.data_sources.find_or_create_by!(name: 'weather') do |ds|
  ds.source_type = 'weather'
  ds.api_endpoint = 'https://api.openweathermap.org/data/2.5/weather'
  ds.api_key = 'demo_key' # Replace with actual API key
  ds.configuration = {
    'default_city' => 'London',
    'units' => 'metric',
    'cache_duration' => 60
  }
  ds.active = true
end

stock_source = user.data_sources.find_or_create_by!(name: 'stocks') do |ds|
  ds.source_type = 'stock'
  ds.api_endpoint = 'https://www.alphavantage.co/query'
  ds.api_key = 'demo' # Replace with actual API key
  ds.configuration = {
    'default_symbol' => 'AAPL',
    'cache_duration' => 300
  }
  ds.active = true
end

location_source = user.data_sources.find_or_create_by!(name: 'location') do |ds|
  ds.source_type = 'location'
  ds.api_endpoint = 'https://ipapi.co'
  ds.configuration = {
    'cache_duration' => 1440
  }
  ds.active = true
end

# Create a dynamic report template
dynamic_report = PdfTemplate.find_or_create_by!(name: "Dynamic Business Report") do |template|
  template.user = user
  template.description = "A business report with live weather, stock, and location data"
  template.template_content = <<~'HTML'
    <div class="report-container">
      <header class="mb-8">
        <h1 class="text-3xl font-bold text-center text-gray-800">{{report_title}}</h1>
        <p class="text-center text-gray-600 mt-2">{{report_date}}</p>
      </header>
      
      <section class="mb-8 bg-blue-50 p-4 rounded">
        <h2 class="text-2xl font-semibold mb-4">Current Conditions</h2>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <h3 class="font-semibold">Weather in {{weather.city}}</h3>
            <p>Temperature: {{weather.temp}}°C</p>
            <p>Condition: {{weather.condition}}</p>
            <p>Humidity: {{weather.humidity}}%</p>
          </div>
          <div>
            <h3 class="font-semibold">Your Location</h3>
            <p>City: {{location.city}}</p>
            <p>Country: {{location.country}}</p>
            <p>Timezone: {{location.timezone}}</p>
          </div>
        </div>
      </section>
      
      <section class="mb-8">
        <h2 class="text-2xl font-semibold mb-4">Market Update</h2>
        <div class="bg-green-50 p-4 rounded">
          <h3 class="font-semibold">{{stocks.symbol}} Stock Performance</h3>
          <p class="text-2xl font-bold">${{stocks.price}}</p>
          <p class="text-lg">Change: {{stocks.change_percent}}%</p>
          <p>Volume: {{stocks.volume}}</p>
          <p>Previous Close: ${{stocks.previous_close}}</p>
        </div>
      </section>
      
      <section>
        <h2 class="text-2xl font-semibold mb-4">Executive Summary</h2>
        <p class="text-gray-700 leading-relaxed">{{executive_summary}}</p>
      </section>
    </div>
  HTML
  template.active = true
end

# Link data sources to the dynamic template
dynamic_report.template_data_sources.find_or_create_by!(data_source: weather_source)
dynamic_report.template_data_sources.find_or_create_by!(data_source: stock_source)
dynamic_report.template_data_sources.find_or_create_by!(data_source: location_source)

puts "Created data sources and dynamic templates!"