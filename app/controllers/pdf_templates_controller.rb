class PdfTemplatesController < ApplicationController
  before_action :set_pdf_template, only: [:show, :edit, :update, :destroy]

  def index
    @pdf_templates = current_user.admin? ? PdfTemplate.all.order(created_at: :desc) : current_user.pdf_templates.order(created_at: :desc)
  end

  def show
    @processed_pdfs = @pdf_template.processed_pdfs.recent.limit(10)
  end

  def new
    @pdf_template = PdfTemplate.new
  end

  def create
    @pdf_template = current_user.pdf_templates.build(pdf_template_params)
    
    if @pdf_template.save
      redirect_to @pdf_template, notice: 'PDF template was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @pdf_template.update(pdf_template_params)
      redirect_to @pdf_template, notice: 'PDF template was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @pdf_template.destroy
    redirect_to pdf_templates_url, notice: 'PDF template was successfully destroyed.'
  end

  private

  def set_pdf_template
    @pdf_template = current_user.admin? ? PdfTemplate.find(params[:id]) : current_user.pdf_templates.find(params[:id])
  end

  def pdf_template_params
    params.require(:pdf_template).permit(:name, :description, :template_content, :active)
  end
end