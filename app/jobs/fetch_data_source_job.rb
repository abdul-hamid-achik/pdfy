class FetchDataSourceJob < ApplicationJob
  queue_as :default

  def perform(data_source_id)
    data_source = DataSource.find(data_source_id)
    result = data_source.fetch_data
    
    # Store the fetched data if successful
    if result.success?
      data_source.data_points.create!(
        key: 'scheduled_fetch',
        value: result.data,
        fetched_at: Time.current,
        expires_at: Time.current + 1.hour,
        metadata: result.metadata
      )
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "DataSource not found: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Error fetching data for DataSource #{data_source_id}: #{e.message}"
    # Re-raise to let Sidekiq handle retries
    raise
  end
end