class Authentication::Email::InviteConfirmationsController < ApplicationController
  before_action :set_invite_token, only: [:new, :create]
  before_action :set_invite, only: [:new, :create]
  before_action :check_valid_invitation, only: [:new]
  before_action :check_accepted_invitation, only: [:new]
  helper_method :current_user

  def new
    @acceptable = true
    if @token.present?
      @organization = @invite.organization
    else
      raise ActionController::RoutingError
    end

    if current_user.present? && @invite.recipient != current_user
      @acceptable = false
      flash.now[:error] = t("invitation.flash.already_signed_in.existing_user", current_email: current_user.email, new_email: @invite.recipient.email)
    end
  end

  def create
    if @invite && Accounts::User.add_via_email(@invite)
      redirect_to root_path, notice: t("invitation.flash.accepted")
    else
      redirect_to root_path, flash: {error: t("invitation.flash.failed")}
    end
  end

  private

  def check_valid_invitation
    if @invite.nil?
      redirect_to root_path, flash: {error: t("invitation.flash.invalid_or_expired")}
    end
  end

  def check_accepted_invitation
    redirect_to root_path, notice: t("invitation.flash.already_accepted") if @invite.accepted?
  end

  def set_invite_token
    @token = params[:invite_token]
  end

  def set_invite
    @invite = Accounts::Invite.find_by(token: @token) if @token.present?
  end
end
