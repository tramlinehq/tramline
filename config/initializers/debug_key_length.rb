Rails.application.config.after_initialize do
  begin
    key_base = Rails.application.credentials.secret_key_base
    Rails.logger.info "Encryption key length: #{key_base&.length || 'nil'}"
  rescue => e
    Rails.logger.error "Error checking key length: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end
