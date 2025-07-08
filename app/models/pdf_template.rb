class PdfTemplate < ApplicationRecord
  belongs_to :user, optional: true
  has_many :processed_pdfs, dependent: :destroy
  has_many :template_data_sources, dependent: :destroy
  has_many :data_sources, through: :template_data_sources
  
  validates :name, presence: true, uniqueness: true
  validates :template_content, presence: true
  
  scope :active, -> { where(active: true) }
  
  def variable_names
    template_content.scan(/\{\{([^}]+)\}\}/).flatten.map(&:strip).uniq
  end
  
  def render_with_variables(variables = {})
    rendered_content = template_content.dup
    
    # Merge user variables with dynamic data
    all_variables = variables.merge(fetch_dynamic_data)
    
    all_variables.each do |key, value|
      rendered_content.gsub!("{{#{key}}}", value.to_s)
    end
    
    rendered_content
  end
  
  def fetch_dynamic_data
    dynamic_data = {}
    
    template_data_sources.enabled.includes(:data_source).each do |template_data_source|
      data_source = template_data_source.data_source
      next unless data_source.active?
      
      # Extract data source variables from template
      data_source_pattern = /\{\{#{data_source.name}\.([^}]+)\}\}/
      matches = template_content.scan(data_source_pattern)
      
      matches.each do |match|
        key = match[0]
        full_key = "#{data_source.name}.#{key}"
        
        begin
          value = data_source.cached_data(key)
          dynamic_data[full_key] = format_dynamic_value(value, key)
        rescue => e
          Rails.logger.error "Failed to fetch data for #{full_key}: #{e.message}"
          dynamic_data[full_key] = "[Data unavailable]"
        end
      end
    end
    
    dynamic_data
  end
  
  private
  
  def format_dynamic_value(value, key)
    return value unless value.is_a?(Hash)
    
    # If the key requests a specific field, extract it
    if key.include?('.')
      keys = key.split('.')
      result = value
      keys.each { |k| result = result[k] if result.is_a?(Hash) }
      result
    else
      value[key] || value.to_s
    end
  end
end