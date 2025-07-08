class HealthController < ApplicationController
  skip_before_action :authenticate_user!

  def check
    status = {
      status: 'ok',
      timestamp: Time.current.iso8601,
      environment: Rails.env,
      version: ENV['APP_VERSION'] || 'unknown',
      services: {}
    }

    # Check database connection
    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
      status[:services][:database] = 'healthy'
    rescue => e
      status[:services][:database] = 'unhealthy'
      status[:status] = 'degraded'
    end

    # Check Redis connection
    begin
      Redis.new(url: ENV['REDIS_URL']).ping
      status[:services][:redis] = 'healthy'
    rescue => e
      status[:services][:redis] = 'unhealthy'
      status[:status] = 'degraded'
    end

    # Check Sidekiq
    begin
      require 'sidekiq/api'
      stats = Sidekiq::Stats.new
      status[:services][:sidekiq] = {
        status: 'healthy',
        processed: stats.processed,
        failed: stats.failed,
        queues: stats.queues
      }
    rescue => e
      status[:services][:sidekiq] = 'unhealthy'
      status[:status] = 'degraded'
    end

    http_status = status[:status] == 'ok' ? :ok : :service_unavailable
    render json: status, status: http_status
  end
end