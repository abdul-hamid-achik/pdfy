class DataSource < ApplicationRecord
  belongs_to :user
  has_many :data_points, dependent: :destroy
  has_many :template_data_sources, dependent: :destroy
  has_many :pdf_templates, through: :template_data_sources
  
  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :source_type, presence: true, inclusion: { in: %w[weather stock news location custom] }
  validates :api_endpoint, presence: true
  
  scope :active, -> { where(active: true) }
  
  encrypts :api_key
  
  def fetch_data(parameters = {})
    case source_type
    when 'weather'
      WeatherService.new(self).fetch(parameters)
    when 'stock'
      StockService.new(self).fetch(parameters)
    when 'news'
      NewsService.new(self).fetch(parameters)
    when 'location'
      LocationService.new(self).fetch(parameters)
    when 'custom'
      CustomApiService.new(self).fetch(parameters)
    end
  end
  
  def cached_data(key, parameters = {})
    data_point = data_points.where(key: key)
                           .where('expires_at > ?', Time.current)
                           .order(fetched_at: :desc)
                           .first
    
    if data_point.nil?
      data_point = fetch_and_store_data(key, parameters)
    end
    
    data_point&.value
  end
  
  def needs_refresh?
    return true if data_points.empty?
    
    latest_point = data_points.order(fetched_at: :desc).first
    latest_point.expires_at < Time.current
  end
  
  private
  
  def fetch_and_store_data(key, parameters)
    result = fetch_data(parameters)
    return nil unless result.success?
    
    data_points.create!(
      key: key,
      value: result.data,
      fetched_at: Time.current,
      expires_at: Time.current + cache_duration,
      metadata: result.metadata
    )
  end
  
  def cache_duration
    configuration&.dig('cache_duration')&.to_i&.minutes || 1.hour
  end
end