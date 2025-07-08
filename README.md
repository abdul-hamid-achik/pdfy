# PDFy

A modern Rails PDF generation and template management application built with Rails 8, featuring user authentication, admin panel, cloud storage integration, and dynamic data from external APIs. Create, manage, and generate PDFs from customizable templates with real-time data including weather, stock prices, news, and location information.

## Features

- **User Authentication**: Secure user registration and login with Devise
- **PDF Template Management**: Create and manage reusable PDF templates with variables
- **Rich Text Editor**: Built-in Trix editor for creating beautiful HTML templates
- **Variable Substitution**: Define variables in templates using `{{variable_name}}` syntax
- **Dynamic Data Integration**: 
  - **Weather Data**: Real-time weather information from OpenWeatherMap
  - **Stock Prices**: Live stock quotes from Alpha Vantage
  - **News Feed**: Latest news articles from NewsAPI
  - **Location Data**: IP-based geolocation information
  - **Custom APIs**: Support for any REST API integration
- **Data Caching**: Intelligent caching system to minimize API calls
- **PDF Generation**: Generate PDFs from templates with custom data using Grover (Chrome-based)
- **Template Library**: Pre-built templates including dynamic business reports
- **PDF History**: Track all generated PDFs with their original HTML and variables used
- **Admin Panel**: Comprehensive admin interface built with ActiveAdmin
- **User Management**: Admin users can manage all users, templates, and PDFs
- **Cloud Storage**: MinIO integration for scalable file storage
- **Modern UI**: Clean, responsive interface built with Tailwind CSS

## Tech Stack

- Ruby 3.4.2
- Rails 8.0.2
- PostgreSQL (all environments)
- MinIO for file storage
- Grover for PDF generation
- Trix for rich text editing
- Devise for authentication
- ActiveAdmin for administration
- Tailwind CSS for styling
- Docker & Docker Compose for containerization

## Prerequisites

### Local Development
- Ruby 3.4.2 or higher
- Node.js and Yarn
- PostgreSQL
- Chrome/Chromium (for PDF generation)

### Docker Development
- Docker
- Docker Compose

## Installation

### Docker Development (Recommended)

1. Clone the repository:
```bash
git clone https://github.com/abdul-hamid-achik/pdfy.git
cd pdfy
```

2. Run the automated setup script:
```bash
bin/docker-setup
```

This will:
- Build Docker containers with all dependencies
- Install Chrome/Chromium for PDF generation  
- Setup PostgreSQL, Redis, and MinIO
- Run database migrations and seed data
- Validate the setup with automated tests

The application will be available at `http://localhost:5050`.
MinIO console will be available at `http://localhost:9001` (login: minioadmin/minioadmin).

#### Manual Docker Setup

If you prefer manual setup:
```bash
docker-compose up --build
docker-compose exec web bin/rails db:create db:migrate db:seed
```

### Local Development

1. Clone the repository:
```bash
git clone https://github.com/abdul-hamid-achik/pdfy.git
cd pdfy
```

2. Install dependencies:
```bash
bundle install
yarn install
```

3. Setup PostgreSQL database:
```bash
# Create a PostgreSQL user
createuser -s pdfy

# Update database.yml with your PostgreSQL credentials
```

4. Setup the database:
```bash
bin/rails db:create db:migrate db:seed
```

5. Configure MinIO (optional for local development):
```bash
# Install MinIO locally or use the Docker version
# Update config/storage.yml with your MinIO credentials
```

6. Start the development server:
```bash
bin/dev
```

The application will be available at `http://localhost:5050`.

## Default Users

After seeding the database, you'll have these default users:

**Admin User:**
- Email: admin@example.com
- Password: password

**Regular User:**
- Create one by signing up at `/users/sign_up`

## Usage

### User Features

1. **Creating a Template**:
   - Sign in to your account
   - Navigate to Templates
   - Click "New Template"
   - Enter name and description
   - Use the rich text editor to create your template
   - Add variables using `{{variable_name}}` syntax
   - Save the template

2. **Generating a PDF**:
   - Select a template from your list
   - Click "Generate PDF"
   - Fill in the required variables
   - Click "Generate PDF"
   - View or download the generated PDF

3. **Managing PDFs**:
   - View all your generated PDFs from the template page
   - Download PDFs anytime
   - See the original HTML and variables used

### Admin Features

1. **Access Admin Panel**:
   - Login as admin user
   - Click "Admin" in the navigation
   - Access comprehensive admin dashboard

2. **Manage Users**:
   - View all users
   - Edit user details
   - Grant/revoke admin privileges
   - View user statistics

3. **Manage Templates**:
   - View all templates across all users
   - Edit any template
   - Activate/deactivate templates
   - View template usage statistics

4. **Manage PDFs**:
   - View all generated PDFs
   - Download any PDF
   - View generation details and metadata

## Template Variables

Variables in templates use double curly brace syntax:
- `{{customer_name}}` - Will be replaced with the customer name
- `{{invoice_date}}` - Will be replaced with the invoice date
- Any text within `{{}}` becomes a variable

### Dynamic Data Variables

When data sources are connected to a template, you can use dynamic variables:

**Weather Data:**
- `{{weather.temp}}` - Current temperature
- `{{weather.condition}}` - Weather condition (Clear, Cloudy, etc.)
- `{{weather.humidity}}` - Humidity percentage
- `{{weather.city}}` - City name
- `{{weather.wind_speed}}` - Wind speed

**Stock Data:**
- `{{stocks.symbol}}` - Stock symbol
- `{{stocks.price}}` - Current price
- `{{stocks.change_percent}}` - Percentage change
- `{{stocks.volume}}` - Trading volume
- `{{stocks.previous_close}}` - Previous closing price

**Location Data:**
- `{{location.city}}` - City name
- `{{location.country}}` - Country name
- `{{location.timezone}}` - Timezone
- `{{location.latitude}}` - Latitude
- `{{location.longitude}}` - Longitude

**News Data:**
- `{{news.0.title}}` - First article title
- `{{news.0.description}}` - First article description
- `{{news.0.url}}` - First article URL

## Environment Variables

### Required for Production
```bash
RAILS_MASTER_KEY=your_master_key
DATABASE_URL=postgresql://user:pass@host:5432/dbname
MINIO_ENDPOINT=https://your-minio-endpoint.com
MINIO_ACCESS_KEY_ID=your_access_key
MINIO_SECRET_ACCESS_KEY=your_secret_key
MINIO_BUCKET=your-bucket-name
```

### Optional
```bash
RAILS_ENV=production
REDIS_URL=redis://localhost:6379/0
CHROME_BIN=/usr/bin/google-chrome
```

## Architecture

### Models
- **User**: Authentication and authorization
- **AdminUser**: Separate admin authentication
- **PdfTemplate**: Stores template name, content, and metadata
- **ProcessedPdf**: Stores generated PDFs with original HTML and variables

### Storage
- **Active Storage**: File attachment management
- **MinIO**: S3-compatible object storage for PDFs
- **PostgreSQL**: Primary database for all data

### Security
- **Authentication**: Devise for secure user sessions
- **Authorization**: User-based template access control
- **Admin Separation**: Separate admin authentication system

## Development

### Running Tests
```bash
bin/rails test
```

### Code Style
```bash
bin/rubocop
```

### Database Console
```bash
bin/rails db
```

### Rails Console
```bash
bin/rails console
```

## Production Deployment

### Railway Deployment

PDFy includes built-in Rails tasks for easy Railway deployment:

```bash
# Validate readiness for deployment
bin/rails deploy:validate

# Prepare for Railway deployment
bin/rails deploy:railway

# Setup Railway services and environment
bin/rails railway:setup
bin/rails railway:env

# Deploy to Railway
bin/rails railway:deploy
```

### Infrastructure as Code

Railway uses native configuration files for infrastructure as code:

- `railway.toml` - Deployment configuration
- `docker-compose.yml` - Development environment
- Rails tasks for deployment automation

### Traditional Server Deployment with Kamal

Rails 8 includes Kamal 2 for server deployments:

```bash
# Configure your servers in config/deploy.yml
bin/kamal setup
bin/kamal deploy
```

For detailed deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

## Troubleshooting

### PDF Generation Issues
- Ensure Chrome is installed in the container/system
- Check Grover configuration
- Verify template HTML is valid
- Check logs: `docker-compose logs web`

### Storage Issues
- Verify MinIO is running: `docker-compose ps minio`
- Check MinIO credentials in environment
- Ensure bucket exists in MinIO
- Access MinIO console at http://localhost:9001

### Database Issues
- Check PostgreSQL is running
- Verify DATABASE_URL is correct
- Run migrations: `bin/rails db:migrate`
- Check credentials in database.yml

### Authentication Issues
- Clear browser cookies
- Restart the application
- Check Devise configuration
- Verify mailer configuration for password resets

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is open source and available under the [MIT License](LICENSE).

## Author

abdul hamid

## Acknowledgments

- Rails 8 for the amazing framework
- Grover for reliable PDF generation
- MinIO for S3-compatible storage
- ActiveAdmin for the admin interface
- Devise for authentication