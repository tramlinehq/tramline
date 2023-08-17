class SignedInApplicationController < ApplicationController
  DEFAULT_TIMEZONE = "Asia/Kolkata"
  before_action :set_paper_trail_whodunnit
  before_action :set_sentry_context, if: -> { Rails.env.production? }
  before_action :require_login, unless: :devise_controller?
  helper_method :current_organization
  helper_method :current_user
  helper_method :writer?
  layout -> { ensure_supported_layout("signed_in_application") }

  rescue_from NotAuthorizedError, with: :user_not_authorized

  protected

  helper_method :demo_org?, :demo_train?, :subscribed_org?, :billing?, :billing_link

  def demo_org?
    current_organization&.demo?
  end

  def subscribed_org?
    current_organization.subscribed?
  end

  def owner?
    current_user.owner_for?(current_organization)
  end

  def billing?
    subscribed_org? && owner?
  end

  def billing_link
    return unless billing?
    return if ENV["BILLING_URL"].blank?

    Addressable::Template
      .new(ENV["BILLING_URL"] + "{?prefilled_email}")
      .expand(prefilled_email: current_organization.owner.email)
      .to_s
  end

  def require_login
    unless current_user
      flash[:error] = t("errors.messages.not_logged_in")
      redirect_to root_path
    end
  end

  def user_not_authorized
    flash[:error] = "You are not authorized to perform this action."
    referrer = (request.referer == request.url) ? root_path : request.referer
    redirect_to(referrer || root_path)
  end

  def require_write_access!
    raise NotAuthorizedError unless writer?
  end

  def writer?
    current_user.writer_for?(current_organization)
  end

  def set_time_zone
    tz = @app.present? ? @app.timezone : DEFAULT_TIMEZONE
    Time.use_zone(tz) { yield }
  end

  def current_organization
    @current_organization ||=
      if session[:active_organization]
        begin
          Accounts::Organization.friendly.find(session[:active_organization])
        rescue ActiveRecord::RecordNotFound
          current_user.organizations.first
        end
      else
        current_user.organizations.first
      end
  end

  def set_sentry_context
    Sentry.set_user(id: current_user.id, username: current_user.full_name, email: current_user.email) if current_user
  end
end
