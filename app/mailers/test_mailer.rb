class TestMailer < ApplicationMailer
  def verify
    @user = Accounts::User.find(params[:user_id])
    mail(to: @user.email, subject: "Test email from Tramline")
  end
end
