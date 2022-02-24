class Authentication::InviteConfirmationsController < ApplicationController
  before_action :set_invite_token, only: [:new, :create]
  before_action :set_invite, only: [:new, :create]

  def new
    if @token.present?
      @organization = @invite.organization
    else
      raise ActionController::RoutingError
    end
  end

  def create
    @invite.recipient.add!(@invite) if @token.present?
    redirect_to new_user_session_path
  rescue ActiveRecord::RecordInvalid
    redirect_to new_user_session_path, notice: "Failed to accept your invitation. Please contact support!"
  end

  private

  def set_invite_token
    @token = params[:invite_token]
  end

  def set_invite
    @invite = Accounts::Invite.find_by_token(@token) if @token.present?
  end
end
