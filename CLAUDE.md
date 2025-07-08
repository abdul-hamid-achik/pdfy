# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PDFy is a Rails 8 PDF generation application with user authentication, template management, and dynamic data integration from external APIs. It uses Railway for deployment with Railway Volumes for file storage.

## Common Development Commands

### Docker Development (Recommended)
```bash
# Initial setup (automated)
bin/docker-setup

# Manual setup
docker-compose up --build
docker-compose exec web bin/rails db:create db:migrate db:seed

# Access Rails console
docker-compose exec web bin/rails console

# Run tests
docker-compose exec web bin/rails test
docker-compose exec web bin/rails test test/models/user_test.rb  # Single test file

# Database operations
docker-compose exec web bin/rails db:migrate
docker-compose exec web bin/rails db:conditional_seed
docker-compose exec web bin/rails db:health

# Access container shell
docker-compose exec web bash
```

### Local Development
```bash
# Start development server
bin/dev

# Run tests
bin/rails test
bin/rails test test/models/user_test.rb:10  # Single test method

# Linting
bin/rubocop
bin/rubocop -a  # Auto-fix

# Asset compilation
yarn build       # JavaScript
yarn build:css   # Tailwind CSS
```

### Deployment Commands
```bash
# Railway deployment validation
bin/rails deploy:validate

# Deploy to Railway
bin/rails railway:deploy
bin/rails railway:status
bin/rails railway:logs

# Environment setup
bin/rails railway:env
```

## Architecture Overview

### Core Models & Relationships
- **User** → has_many PdfTemplates, DataSources (Devise authentication)
- **PdfTemplate** → belongs_to User, has_many ProcessedPdfs, has_many DataSources through TemplateDataSources
  - Variables use `{{variable_name}}` syntax
  - Dynamic data accessed via `{{data_source.field}}` (e.g., `{{weather.temperature}}`)
- **ProcessedPdf** → belongs_to PdfTemplate, has_attached :pdf_file (Active Storage)
- **DataSource** → belongs_to User, has_many DataPoints, connects to external APIs
  - Types: weather, stock, news, location, custom
  - Encrypts API keys using Active Record encryption
- **DataPoint** → cached API responses with expiration

### Service Layer Architecture
All API integrations inherit from `BaseApiService`:
- **WeatherService** - OpenWeatherMap integration
- **StockService** - Alpha Vantage integration  
- **NewsService** - NewsAPI integration
- **LocationService** - IP-based geolocation
- **CustomApiService** - Generic REST API support

Services return standardized response objects with success/failure states and metadata.

### Background Jobs
- **FetchDataSourceJob** - Fetches and caches individual data source
- **RefreshAllDataSourcesJob** - Bulk refresh of expired data sources
- Uses Sidekiq with Redis backend

### PDF Generation Flow
1. User creates template with variables → `PdfTemplate`
2. Template optionally connects to data sources → `TemplateDataSource`
3. User generates PDF → `ProcessedPdfsController#create`
   - Fetches dynamic data via services
   - Renders HTML with variable substitution
   - Generates PDF using Grover (Chrome/Puppeteer)
   - Stores PDF in Active Storage

### Storage Architecture
- **Production**: Railway Volumes mounted at `/app/storage`
- **Development**: Local disk or optional MinIO (S3-compatible)
- **Test**: Temporary storage
- Configured via `STORAGE_ROOT` environment variable

## Key Configuration Files

### Railway Deployment
- `railway.toml` - Railway platform configuration with volume mounts
- Uses native Railway configuration, no external storage dependencies
- Volumes provide persistent storage across deployments

### Environment Variables
Required for production:
- `RAILS_MASTER_KEY` - Rails encryption key
- `DATABASE_URL` - PostgreSQL connection
- `REDIS_URL` - Redis for Sidekiq/caching
- `STORAGE_ROOT` - File storage path (set to `/app/storage` on Railway)

Optional API keys:
- `OPENWEATHER_API_KEY`
- `ALPHA_VANTAGE_API_KEY`
- `NEWS_API_KEY`

### Test Environment
- Uses `:test` Active Job adapter for job testing
- Requires test credentials in `config/credentials/test.yml.enc`
- WebMock for API stubbing

## Important Patterns

### Variable Rendering
Templates use Mustache-style variables:
```ruby
# In template: "Hello {{name}}, the weather is {{weather.condition}}"
# Rendered via: template.render_with_variables(name: "John")
```

### API Data Caching
Data sources cache responses with configurable TTL:
```ruby
data_source.cached_data("temperature") # Returns cached or fetches new
```

### Admin Interface
ActiveAdmin at `/admin` with separate authentication (`AdminUser` model).

## Testing Approach

- Fixtures for all models in `test/fixtures/`
- Integration tests for full workflows
- Service tests use WebMock stubs
- Job tests require Active Job test adapter
- System tests use headless Chrome

## Known Issues & Solutions

### Test Failures
- Ensure `config.active_job.queue_adapter = :test` in test environment
- Admin user fixtures must have unique emails
- PDF tests require file attachments (see `test/models/processed_pdf_test.rb` setup)

### Docker Development
- Chrome/Chromium required for PDF generation (included in Dockerfile)
- MinIO optional - defaults to local storage
- Use `docker-compose exec` for all Rails commands

### Production Deployment
- Railway Volumes limited to single volume per service
- No direct file browser - access files through application
- Automatic asset compilation during deployment