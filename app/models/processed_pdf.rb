class ProcessedPdf < ApplicationRecord
  belongs_to :pdf_template
  
  has_one_attached :pdf_file
  
  validates :original_html, presence: true
  validates :pdf_file, attached: true, on: :update
  
  before_validation :set_generated_at, on: :create
  
  scope :recent, -> { order(generated_at: :desc) }
  
  def filename
    timestamp = generated_at || Time.current
    "#{pdf_template.name.parameterize}_#{timestamp.strftime('%Y%m%d_%H%M%S')}.pdf"
  end
  
  private
  
  def set_generated_at
    self.generated_at ||= Time.current
  end
end