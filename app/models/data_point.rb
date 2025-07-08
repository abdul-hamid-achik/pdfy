class DataPoint < ApplicationRecord
  belongs_to :data_source
  
  validates :key, presence: true
  validates :fetched_at, presence: true
  validates :expires_at, presence: true
  validate :expires_at_must_be_after_fetched_at
  validate :value_must_not_be_nil
  
  scope :current, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :by_key, ->(key) { where(key: key) }
  scope :recent, -> { order(fetched_at: :desc) }
  
  def expired?
    expires_at.present? && expires_at <= Time.current
  end
  
  def formatted_value
    case data_source.source_type
    when 'weather'
      format_weather_data
    when 'stock'
      format_stock_data
    when 'news'
      format_news_data
    else
      value
    end
  end
  
  private
  
  def expires_at_must_be_after_fetched_at
    return unless fetched_at.present? && expires_at.present?
    
    if expires_at < fetched_at
      errors.add(:expires_at, "must be after fetched_at")
    end
  end
  
  def value_must_not_be_nil
    if value.nil?
      errors.add(:value, "can't be blank")
    elsif value.is_a?(Array) && value.empty?
      errors.add(:value, "can't be blank")
    end
  end
  
  def format_weather_data
    return value unless value.is_a?(Hash)
    
    {
      temperature: "#{value['temp']}°C",
      condition: value['condition'],
      humidity: "#{value['humidity']}%",
      wind_speed: "#{value['wind_speed']} km/h"
    }
  end
  
  def format_stock_data
    return value unless value.is_a?(Hash)
    
    {
      symbol: value['symbol'],
      price: "$#{value['price']}",
      change: "#{value['change']}%",
      volume: value['volume']
    }
  end
  
  def format_news_data
    return value unless value.is_a?(Array)
    
    value.map do |article|
      {
        title: article['title'],
        summary: article['summary'],
        url: article['url'],
        published_at: article['published_at']
      }
    end
  end
end