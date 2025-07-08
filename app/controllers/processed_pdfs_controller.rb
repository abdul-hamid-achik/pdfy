class ProcessedPdfsController < ApplicationController
  before_action :set_pdf_template
  before_action :set_processed_pdf, only: [:show, :download]

  def show
  end

  def new
    @processed_pdf = @pdf_template.processed_pdfs.build
    @variables = @pdf_template.variable_names
  end

  def create
    @processed_pdf = @pdf_template.processed_pdfs.build(processed_pdf_params)
    
    # Render template with variables
    variables = params[:variables] || {}
    rendered_html = @pdf_template.render_with_variables(variables)
    
    # Store original HTML and variables used
    @processed_pdf.original_html = rendered_html
    @processed_pdf.variables_used = variables
    
    # Generate PDF using Grover
    begin
      pdf_content = generate_pdf(rendered_html)
      
      @processed_pdf.pdf_file.attach(
        io: StringIO.new(pdf_content),
        filename: @processed_pdf.filename,
        content_type: 'application/pdf'
      )
      
      if @processed_pdf.save
        redirect_to pdf_template_processed_pdf_path(@pdf_template, @processed_pdf), 
                    notice: 'PDF was successfully generated.'
      else
        @variables = @pdf_template.variable_names
        render :new, status: :unprocessable_entity
      end
    rescue => e
      @variables = @pdf_template.variable_names
      flash.now[:alert] = "Error generating PDF: #{e.message}"
      render :new, status: :unprocessable_entity
    end
  end

  def download
    redirect_to rails_blob_path(@processed_pdf.pdf_file, disposition: "attachment")
  end

  private

  def set_pdf_template
    @pdf_template = current_user.admin? ? PdfTemplate.find(params[:pdf_template_id]) : current_user.pdf_templates.find(params[:pdf_template_id])
  end

  def set_processed_pdf
    @processed_pdf = @pdf_template.processed_pdfs.find(params[:id])
  end

  def processed_pdf_params
    params.fetch(:processed_pdf, {}).permit(metadata: {})
  end

  def generate_pdf(html_content)
    # Wrap content in a basic HTML structure with Tailwind CSS
    full_html = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <script src="https://cdn.tailwindcss.com"></script>
        </head>
        <body class="p-8">
          #{html_content}
        </body>
      </html>
    HTML
    
    Grover.new(full_html, format: 'A4').to_pdf
  end
end