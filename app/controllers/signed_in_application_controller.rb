class SignedInApplicationController < ApplicationController
  DEFAULT_TIMEZONE = "Asia/Kolkata"
  include MetadataAwareness

  before_action :turbo_frame_request_variant
  before_action :set_currents
  before_action :set_paper_trail_whodunnit
  before_action :set_sentry_context, if: -> { Rails.env.production? }
  before_action :require_login, unless: :devise_controller?
  before_action :track_behaviour
  before_action :set_app
  helper_method :current_organization
  helper_method :current_user
  helper_method :default_app
  helper_method :new_app
  helper_method :writer?
  helper_method :default_timezones
  layout -> { ensure_supported_layout("signed_in_application") }

  rescue_from NotAuthorizedError, with: :user_not_authorized

  protected

  helper_method :demo_org?, :demo_train?, :subscribed_org?, :billing?, :billing_link, :logout_path
  PATH_PARAMS_UNDER_APP = [:id, :app_id, :integration_id, :train_id, :platform_id]

  def logout_path
    destroy_email_authentication_session_path
  end

  def demo_org?
    current_organization&.demo?
  end

  def subscribed_org?
    current_organization&.subscribed?
  end

  def owner?
    current_user&.owner_for?(current_organization)
  end

  def billing?
    subscribed_org? && owner?
  end

  def billing_link
    return unless billing?
    return if ENV["BILLING_URL"].blank?

    Addressable::Template
      .new(ENV["BILLING_URL"] + "{?prefilled_email}")
      .expand(prefilled_email: current_user.email)
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

  def set_sentry_context
    Sentry.set_user(id: current_user.id, username: current_user.full_name, email: current_user.email) if current_user
  end

  def set_currents
    Current.user = current_user
    Current.organization = current_organization
  end

  def track_behaviour
    SiteAnalytics.track(
      current_user,
      current_organization,
      device,
      "#{controller_name} – #{action_name}"
    )
  end

  def set_app
    return if app_id.blank?

    @app = current_organization.apps.friendly.find_by(slug: app_id)
    return if @app.present?

    redirect_config = Rails.application.config.x.app_redirect
    new_app_id = redirect_config[app_id]
    redirect_to url_for(params.permit(*PATH_PARAMS_UNDER_APP).merge(app_id_key => new_app_id)) and return if new_app_id.present?

    @app = current_organization.apps.friendly.find(app_id)
  end

  def default_app
    return if @app.blank? || !@app.persisted?

    if @app.blank?
      current_organization.default_app
    elsif @app.persisted?
      @app
    end
  end

  def new_app
    current_organization.apps.new
  end

  DEFAULT_TIMEZONE_LIST_REGEX = /Asia\/Kolkata/

  def default_timezones
    ActiveSupport::TimeZone.all.select { |tz| tz.match?(DEFAULT_TIMEZONE_LIST_REGEX) }
  end

  def app_id
    params[app_id_key]
  end

  def app_id_key
    :app_id
  end

  def turbo_frame_request_variant
    request.variant = :turbo_frame if turbo_frame_request?
  end
end
