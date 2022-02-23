class InvitationMailer < ActionMailer::Base
  def existing_user(invite)
    @invite = invite

    mail(
      from: @invite.sender.email,
      to: @invite.email,
      subject: I18n.t("invitation.invite_mailer.existing_user.subject")
    )
  end

  def new_user(invite)
    @invite = invite
    @user_registration_url = @invite.registration_url

    mail(
      from: @invite.sender.email,
      to: @invite.email,
      subject: I18n.t("invitation.invite_mailer.new_user.subject")
    )
  end
end
