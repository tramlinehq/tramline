class InvitationMailer < ApplicationMailer
  def existing_user(invite)
    @invite = invite
    @user_invite_accept_url = @invite.accept_url

    mail(
      to: @invite.email,
      subject: I18n.t("invitation.invite_mailer.existing_user.subject")
    )
  end

  def new_user(invite)
    @invite = invite
    @user_registration_url = @invite.registration_url

    mail(
      to: @invite.email,
      subject: I18n.t("invitation.invite_mailer.new_user.subject")
    )
  end
end
