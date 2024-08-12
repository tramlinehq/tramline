InvisibleCaptcha.setup do |config|
  config.visual_honeypots = Rails.env.development?
end

ActiveSupport::Notifications.subscribe("invisible_captcha.spam_detected") do |*args, data|
  Rails.logger.warn(data[:message], data)
end
