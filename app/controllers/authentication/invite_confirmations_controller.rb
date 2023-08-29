class Authentication::InviteConfirmationsController < ApplicationController
  before_action :set_invite_token, only: [:new, :create]
  before_action :set_invite, only: [:new, :create]
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
      flash[:error] = "You are signed in as #{current_user.email} in Tramline. Log out to accept the invite for #{@invite.recipient.email}."
    end
  end

  def create
    @invite.recipient.add!(@invite) if @token.present?
    redirect_to new_user_session_path
  rescue ActiveRecord::RecordInvalid
    redirect_to new_user_session_path, notice: "Failed to accept your invitation. Please contact support!"
  end

  private

  def check_accepted_invitation
    redirect_to root_path, notice: "Invitation was accepted!" if @invite.accepted_at.present?
  end

  def set_invite_token
    @token = params[:invite_token]
  end

  def set_invite
    @invite = Accounts::Invite.find_by(token: @token) if @token.present?
  end
end
