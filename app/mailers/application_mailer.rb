class ApplicationMailer < ActionMailer::Base
  default from: "no-reply@tramline.app"
  layout "mailer"
end
