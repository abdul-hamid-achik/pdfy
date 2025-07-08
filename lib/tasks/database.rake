namespace :db do
  desc "Setup database with conditional seeding for production"
  task conditional_seed: :environment do
    if Rails.env.production?
      # Only seed if database is empty (no users exist)
      if User.count == 0
        puts "Database is empty in production, running seeds..."
        Rake::Task['db:seed'].invoke
        puts "Production database seeded successfully!"
      else
        puts "Database already contains data, skipping seeding in production"
      end
    else
      # Always seed in development/test
      puts "Running seeds for #{Rails.env} environment..."
      Rake::Task['db:seed'].invoke
      puts "#{Rails.env.capitalize} database seeded successfully!"
    end
  end

  desc "Reset database safely in production"
  task safe_reset: :environment do
    if Rails.env.production?
      puts "ERROR: Cannot reset production database for safety reasons"
      puts "If you really need to reset production, use: ALLOW_PRODUCTION_RESET=true rails db:safe_reset"
      exit 1 unless ENV['ALLOW_PRODUCTION_RESET'] == 'true'
    end
    
    Rake::Task['db:reset'].invoke
  end

  desc "Check database health and statistics"
  task health: :environment do
    puts "Database Health Check"
    puts "===================="
    
    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
      puts "✅ Database connection: OK"
    rescue => e
      puts "❌ Database connection: FAILED - #{e.message}"
      exit 1
    end

    puts "\nDatabase Statistics:"
    puts "-------------------"
    puts "Users: #{User.count}"
    puts "PDF Templates: #{PdfTemplate.count}"
    puts "Processed PDFs: #{ProcessedPdf.count}"
    puts "Data Sources: #{DataSource.count}"
    puts "Data Points: #{DataPoint.count}"
    
    if defined?(AdminUser)
      puts "Admin Users: #{AdminUser.count}"
    end

    puts "\nActive Data Sources:"
    DataSource.active.each do |ds|
      latest_data = ds.data_points.order(created_at: :desc).first
      status = latest_data ? "Last updated: #{latest_data.created_at}" : "No data"
      puts "  - #{ds.name} (#{ds.source_type}): #{status}"
    end

    puts "\nRecent Activity:"
    puts "  - Latest template: #{PdfTemplate.order(created_at: :desc).first&.name || 'None'}"
    puts "  - Latest PDF: #{ProcessedPdf.order(created_at: :desc).first&.filename || 'None'}"
  end

  desc "Create sample data for development"
  task sample_data: :environment do
    if Rails.env.production?
      puts "ERROR: Cannot create sample data in production"
      exit 1
    end

    puts "Creating sample data for development..."
    
    # Create additional test users
    3.times do |i|
      user = User.find_or_create_by(email: "user#{i + 2}@example.com") do |u|
        u.password = 'password'
        u.password_confirmation = 'password'
      end
      
      # Create sample templates for each user
      2.times do |j|
        user.pdf_templates.find_or_create_by(name: "Sample Template #{i + 1}-#{j + 1}") do |template|
          template.description = "Sample template for testing"
          template.template_content = "<h1>{{title}}</h1><p>{{content}}</p>"
          template.active = true
        end
      end
    end

    puts "Sample data created successfully!"
  end
end