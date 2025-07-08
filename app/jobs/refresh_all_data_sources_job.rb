class RefreshAllDataSourcesJob < ApplicationJob
  queue_as :low

  def perform
    DataSource.active.find_each do |data_source|
      # Check if data needs refresh (older than cache duration)
      if data_source.needs_refresh?
        FetchDataSourceJob.perform_later(data_source.id)
      end
    end
  end
end