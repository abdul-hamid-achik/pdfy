# Deployment tasks for PDFy
# Rails 8 comes with Kamal for traditional server deployments
# This file provides tasks for Railway and other PaaS deployments

namespace :deploy do
  desc "Prepare application for Railway deployment"
  task :railway => :environment do
    puts "🚀 Preparing PDFy for Railway deployment..."
    
    # Check that we have required credentials
    unless Rails.application.credentials.secret_key_base
      puts "❌ Missing secret_key_base in Rails credentials"
      puts "   Run: EDITOR=nano bin/rails credentials:edit"
      exit 1
    end
    
    # Check for master key
    unless File.exist?("config/master.key")
      puts "❌ Missing config/master.key file"
      puts "   This file should contain your Rails master key"
      exit 1
    end
    
    puts "✅ Rails credentials configured"
    
    # Verify production configuration
    Rake::Task["deploy:check_production_config"].invoke
    
    # Verify Docker configuration
    Rake::Task["deploy:check_docker"].invoke
    
    puts "✅ Application ready for Railway deployment"
    puts ""
    puts "Next steps:"
    puts "1. Connect your repository to Railway: https://railway.app"
    puts "2. Set environment variables in Railway dashboard"
    puts "3. Add PostgreSQL and Redis services"
    puts "4. Deploy from Railway dashboard or CLI"
    puts ""
    puts "Required environment variables:"
    puts "- RAILS_MASTER_KEY=#{File.read('config/master.key').strip}"
    puts "- RAILS_ENV=production"
    puts "- CHROME_BIN=/usr/bin/chromium"
  end
  
  desc "Check production configuration"
  task :check_production_config => :environment do
    puts "🔍 Checking production configuration..."
    
    # Check for production-specific settings
    config_issues = []
    
    # Check if we have proper error reporting
    unless Rails.application.config.consider_all_requests_local == false
      config_issues << "Set config.consider_all_requests_local = false in production"
    end
    
    # Check production asset configuration (Rails 8 with Propshaft)
    # In production, we want to serve static files from public/ folder
    unless Rails.application.config.public_file_server.enabled
      config_issues << "Enable public file server for Railway deployment"
    end
    
    if config_issues.any?
      puts "⚠️  Production configuration issues:"
      config_issues.each { |issue| puts "   - #{issue}" }
    else
      puts "✅ Production configuration looks good"
    end
  end
  
  desc "Check Docker configuration"
  task :check_docker do
    puts "🐳 Checking Docker configuration..."
    
    unless File.exist?("Dockerfile")
      puts "❌ Missing Dockerfile"
      exit 1
    end
    
    unless File.exist?(".dockerignore")
      puts "⚠️  Missing .dockerignore file"
      puts "   Creating basic .dockerignore..."
      File.write(".dockerignore", <<~DOCKERIGNORE)
        .git
        .gitignore
        README.md
        Dockerfile
        .dockerignore
        node_modules
        npm-debug.log*
        .nyc_output
        .env
        coverage
        .nyc_output
        .cache
        tmp
        log
      DOCKERIGNORE
    end
    
    puts "✅ Docker configuration ready"
  end
  
  desc "Setup Railway project configuration"
  task :setup_config => :environment do
    puts "🏗️  Setting up Railway configuration..."
    
    unless File.exist?("railway.toml")
      puts "❌ Missing railway.toml file"
      exit 1
    end
    
    puts "✅ Railway configuration ready"
    puts "   Configuration file: railway.toml"
    puts ""
    puts "Next steps:"
    puts "1. Create Railway project: railway login && railway init"
    puts "2. Connect repository to Railway dashboard"
    puts "3. Add PostgreSQL and Redis services"
    puts "4. Deploy with: railway up"
  end
  
  desc "Validate Railway deployment readiness"
  task :validate => :environment do
    puts "✅ Validating PDFy for Railway deployment..."
    
    validations = [
      { task: "deploy:check_production_config", name: "Production configuration" },
      { task: "deploy:check_docker", name: "Docker configuration" },
      { task: "deploy:check_dependencies", name: "Dependencies" },
      { task: "deploy:check_assets", name: "Asset pipeline" },
      { task: "deploy:setup_config", name: "Railway configuration" }
    ]
    
    validations.each do |validation|
      print "   Checking #{validation[:name]}... "
      begin
        Rake::Task[validation[:task]].invoke
        puts "✅"
      rescue => e
        puts "❌"
        puts "     Error: #{e.message}"
        exit 1
      end
    end
    
    puts ""
    puts "🎉 All validations passed! Ready for deployment."
  end
  
  desc "Check application dependencies"
  task :check_dependencies => :environment do
    required_gems = %w[rails pg redis grover sidekiq]
    
    required_gems.each do |gem_name|
      begin
        require gem_name
      rescue LoadError
        puts "❌ Missing required gem: #{gem_name}"
        puts "   Add to Gemfile: gem '#{gem_name}'"
        exit 1
      end
    end
  end
  
  desc "Check asset pipeline configuration"
  task :check_assets => :environment do
    # Rails 8 uses Propshaft by default, not Sprockets
    # Check if we have assets setup
    
    if File.exist?("app/assets")
      puts "✅ Asset pipeline configured (using Propshaft)"
    else
      puts "⚠️  No assets directory found"
    end
    
    # Check for JavaScript and CSS bundling
    if File.exist?("package.json")
      puts "✅ JavaScript bundling configured"
    else
      puts "⚠️  No package.json found for JavaScript bundling"
    end
    
    # Check for precompiled assets in production
    if Rails.env.production? && !File.exist?("public/assets")
      puts "⚠️  No precompiled assets found"
      puts "   Assets will be compiled during deployment"
    end
  end
end

namespace :railway do
  desc "Deploy to Railway using their CLI"
  task :deploy do
    puts "🚀 Deploying to Railway..."
    
    unless system("which railway > /dev/null 2>&1")
      puts "❌ Railway CLI not found"
      puts "   Install: npm install -g @railway/cli"
      exit 1
    end
    
    # Check if logged in
    unless system("railway whoami > /dev/null 2>&1")
      puts "🔐 Please login to Railway first:"
      system("railway login")
    end
    
    puts "   Uploading code and starting deployment..."
    system("railway up")
  end
  
  desc "Setup Railway services (PostgreSQL, Redis)"
  task :setup do
    puts "🔧 Setting up Railway services..."
    
    puts "   Adding PostgreSQL..."
    system("railway add postgresql")
    
    puts "   Adding Redis..."
    system("railway add redis")
    
    puts "✅ Services configured"
  end
  
  desc "Set Railway environment variables"
  task :env do
    puts "🔧 Setting Railway environment variables..."
    
    master_key = File.read("config/master.key").strip
    
    env_vars = {
      "RAILS_MASTER_KEY" => master_key,
      "RAILS_ENV" => "production",
      "RAILS_LOG_TO_STDOUT" => "true",
      "CHROME_BIN" => "/usr/bin/chromium"
    }
    
    env_vars.each do |key, value|
      puts "   Setting #{key}..."
      system("railway variables set #{key}='#{value}'")
    end
    
    puts "✅ Environment variables set"
    puts ""
    puts "Additional variables you may want to set:"
    puts "- OPENWEATHER_API_KEY (for weather data)"
    puts "- ALPHA_VANTAGE_API_KEY (for stock data)"
    puts "- NEWS_API_KEY (for news data)"
  end
  
  desc "Show Railway application status"
  task :status do
    system("railway status")
  end
  
  desc "Show Railway application logs"
  task :logs do
    system("railway logs")
  end
  
  desc "Open Railway dashboard"
  task :open do
    system("railway open")
  end
end

# Convenient aliases
task "deploy:production" => "deploy:railway"
task "deploy:setup" => "railway:setup"