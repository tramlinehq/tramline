InvisibleCaptcha.setup do |config|
  config.honeypots = %w[family_name display_email passphrase organization_display_name company_name]
  config.visual_honeypots = Rails.env.development?
end

ActiveSupport::Notifications.subscribe("invisible_captcha.spam_detected") do |*args, data|
  Rails.logger.warn(data[:message], data)
end
