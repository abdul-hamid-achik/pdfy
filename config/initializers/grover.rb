Grover.configure do |config|
  config.options = {
    format: 'A4',
    margin: {
      top: '1cm',
      bottom: '1cm',
      left: '1cm',
      right: '1cm'
    },
    viewport: {
      width: 1024,
      height: 768
    },
    prefer_css_page_size: true,
    print_background: true,
    display_header_footer: false,
    wait_until: 'networkidle2',
    launch_args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
  }
  
  # Set Chrome executable path based on environment
  if ENV['CHROME_BIN'].present?
    config.options[:executable_path] = ENV['CHROME_BIN']
  end
end