# Setting Up Sidekiq Worker Service on Railway

This guide explains how to deploy a separate Sidekiq worker service alongside your Rails app on Railway.

## Architecture Overview

You'll have 4 services running:
- **pdfy-web**: Main Rails application
- **pdfy-worker**: Sidekiq background job processor
- **Postgres**: Database
- **Redis**: Job queue for Sidekiq

## Step 1: Create the Worker Service

### Using Railway Dashboard:
1. Go to your Railway project
2. Click "New Service" → "Empty Service"
3. Name it `pdfy-worker`

### Using Railway CLI:
```bash
railway add --service pdfy-worker
```

## Step 2: Configure the Worker Service

1. **Connect your GitHub repository** to the worker service
2. **Set the config file**: In the worker service settings, set:
   - Root Directory: `/` (same as web service)
   - Config Path: `railway-worker.toml`

## Step 3: Set Environment Variables

The worker needs the same environment variables as your web service:

```bash
# Switch to the worker service context
railway service pdfy-worker

# Set all required variables
railway variables --set "RAILS_MASTER_KEY=$RAILS_MASTER_KEY"
railway variables --set "DATABASE_URL=${{Postgres.DATABASE_URL}}"
railway variables --set "REDIS_URL=${{Redis.REDIS_URL}}"
railway variables --set "RAILS_ENV=production"
railway variables --set "RAILS_LOG_TO_STDOUT=true"

# Add any API keys your jobs need
railway variables --set "OPENWEATHER_API_KEY=your_key"
railway variables --set "ALPHA_VANTAGE_API_KEY=your_key"
railway variables --set "NEWS_API_KEY=your_key"
```

## Step 4: Deploy

The worker will automatically deploy when you push to your repository. The `railway-worker.toml` file tells it to run:

```bash
bundle exec sidekiq -C config/sidekiq.yml
```

## Step 5: Monitor Your Worker

### View Logs:
```bash
railway logs --service pdfy-worker
```

### In the Railway Dashboard:
- Click on the pdfy-worker service
- Go to "Deployments" to see status
- Click "View Logs" to monitor job processing

## Sidekiq Configuration Details

Your `config/sidekiq.yml` defines:
- **Concurrency**: 10 workers in production
- **Queues**: critical, default, low (in priority order)
- **Timeout**: 30 seconds per job

## Testing the Setup

1. **Check if Sidekiq is running**:
```bash
railway logs --service pdfy-worker | grep "Booting Sidekiq"
```

2. **Test a job from Rails console**:
```bash
railway run --service pdfy-web rails console

# In console:
FetchDataSourceJob.perform_later(DataSource.first)
```

3. **Monitor job execution**:
```bash
railway logs --service pdfy-worker -f
```

## Troubleshooting

### Worker not starting?
- Check Redis connection: Ensure REDIS_URL is set correctly
- Check logs: `railway logs --service pdfy-worker`

### Jobs not processing?
- Verify Redis is running: Check your Redis service in Railway
- Check job queue: Use Rails console to inspect `Sidekiq::Queue.all`

### Memory issues?
- Reduce concurrency in `config/sidekiq.yml`
- Upgrade your Railway plan for more resources

## Advanced Configuration

### Scaling Workers
You can adjust concurrency based on your needs:
```yaml
# config/sidekiq.yml
production:
  :concurrency: 20  # Increase for more parallel jobs
```

### Adding More Queues
```yaml
:queues:
  - critical
  - mailers
  - default
  - low
  - data_fetch  # Custom queue for data source jobs
```

### Setting Queue Weights
```yaml
:queues:
  - [critical, 6]    # Process 6x more often
  - [default, 3]
  - [low, 1]
```

## Best Practices

1. **Separate Services**: Keep web and worker separate for better resource management
2. **Monitor Memory**: Watch worker memory usage, especially with high concurrency
3. **Use Queues**: Organize jobs by priority (critical, default, low)
4. **Idempotent Jobs**: Design jobs to be safely retryable
5. **Set Timeouts**: Prevent stuck jobs with appropriate timeouts

## Cost Considerations

Running a separate worker service will double your Railway costs, but provides:
- Independent scaling
- Better performance isolation
- Easier debugging
- No impact on web response times

## Next Steps

1. Set up monitoring with Railway metrics
2. Configure alerts for failed jobs
3. Add Sidekiq Web UI for job monitoring (optional)
4. Implement job retry strategies