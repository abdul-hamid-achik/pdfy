class PdfTemplate < ApplicationRecord
  belongs_to :user, optional: true
  has_many :processed_pdfs, dependent: :destroy
  
  validates :name, presence: true, uniqueness: true
  validates :template_content, presence: true
  
  scope :active, -> { where(active: true) }
  
  def variable_names
    template_content.scan(/\{\{([^}]+)\}\}/).flatten.map(&:strip).uniq
  end
  
  def render_with_variables(variables = {})
    rendered_content = template_content.dup
    
    variables.each do |key, value|
      rendered_content.gsub!("{{#{key}}}", value.to_s)
    end
    
    rendered_content
  end
end