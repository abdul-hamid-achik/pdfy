class TemplateDataSource < ApplicationRecord
  belongs_to :pdf_template
  belongs_to :data_source
  
  validates :pdf_template_id, uniqueness: { scope: :data_source_id }
  
  scope :enabled, -> { where(enabled: true) }
end