# This is a temporary file to debug the key length issue and will be removed after the issue is fixed
puts "DEBUG [initializer]: Attempting to debug key issue"

begin
  key_content = ENV["RAILS_MASTER_KEY"]
  puts "DEBUG [initializer]: Master key exists: #{!key_content.nil?}"
  puts "DEBUG [initializer]: Master key length: #{key_content ? key_content.length : 'nil'}"

  # Only log the first and last characters of the key to avoid security issues
  puts "DEBUG [initializer]: Master key first/last char: #{key_content ? "#{key_content[0]}...#{key_content[-1]}" : 'nil'}" if key_content

  # Check credentials file path
  pipeline_env = ENV["RAILS_PIPELINE_ENV"]
  if pipeline_env.present?
    creds_path = Rails.root.join("config/credentials/#{pipeline_env}.yml.enc").to_s
  else
    creds_path = Rails.root.join("config/credentials.yml.enc").to_s
  end
  puts "DEBUG [initializer]: Credentials path: #{creds_path}"
  puts "DEBUG [initializer]: Credentials file exists: #{File.exist?(creds_path)}"

  # Try to access the credentials (safely)
  begin
    creds = Rails.application.credentials.to_h rescue nil
    puts "DEBUG [initializer]: Credentials loaded successfully: #{!creds.nil?}"
    puts "DEBUG [initializer]: Credentials keys: #{creds ? creds.keys.join(', ') : 'none'}" if creds
  rescue => e
    puts "DEBUG [initializer]: Error loading credentials: #{e.class} - #{e.message}"
  end
rescue => e
  puts "DEBUG [initializer]: Error in debugging: #{e.class} - #{e.message}"
end
