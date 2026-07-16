class LifecycleHooksController < SignedInApplicationController
  include Tabbable

  before_action :require_write_access!, only: %i[new create edit update destroy]
  before_action :set_train
  before_action :ensure_app_ready
  before_action :set_train_config_tabs
  before_action :set_notification_channels, only: %i[new create edit update]
  before_action :set_hook, only: %i[edit update destroy]

  def index
    @hooks = @train.lifecycle_hooks.order(created_at: :asc)
  end

  def new
    @hook = @train.lifecycle_hooks.new(http_method: "POST", auth_type: "none", active: true, notify_on_failure: true)
  end

  def edit
  end

  def create
    @hook = @train.lifecycle_hooks.new(parsed_hook_params)
    if @hook.save
      redirect_to app_train_lifecycle_hooks_path(@app, @train), notice: "Lifecycle hook created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    update_params = parsed_hook_params
    update_params = update_params.except(:auth_secret) if update_params[:auth_secret].blank?

    if @hook.update(update_params)
      redirect_to app_train_lifecycle_hooks_path(@app, @train), notice: "Lifecycle hook updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @hook.destroy
    redirect_to app_train_lifecycle_hooks_path(@app, @train), status: :see_other, notice: "Lifecycle hook removed."
  end

  private

  def set_train
    @train = @app.trains.friendly.find(params[:train_id])
  end

  def set_hook
    @hook = @train.lifecycle_hooks.find(params[:id])
  end

  def set_notification_channels
    @notification_channels = @app.notification_provider.channels if @app.notifications_set_up?
  end

  def hook_params
    params.require(:lifecycle_hook).permit(
      :name,
      :event,
      :active,
      :http_method,
      :url,
      :body_template,
      :auth_type,
      :auth_username,
      :auth_secret,
      :notify_on_failure,
      :failure_message_template,
      :headers_text,
      :static_variables_text,
      :failure_notification_channel
    )
  end

  def parsed_hook_params
    permitted = hook_params.to_h.symbolize_keys
    permitted[:headers] = parse_kv_text(permitted.delete(:headers_text))
    permitted[:static_variables] = parse_kv_text(permitted.delete(:static_variables_text))
    permitted[:failure_notification_channel] = parse_channel(permitted[:failure_notification_channel])
    permitted
  end

  def parse_kv_text(text)
    return {} if text.blank?
    text.to_s.each_line.each_with_object({}) do |line, acc|
      key, _, value = line.strip.partition(":")
      next if key.blank?
      acc[key.strip] = value.strip
    end
  end

  def parse_channel(channel_json)
    return nil if channel_json.blank?
    channel_json.is_a?(String) ? JSON.parse(channel_json) : channel_json
  rescue JSON::ParserError
    nil
  end
end
