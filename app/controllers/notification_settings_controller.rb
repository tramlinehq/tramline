class NotificationSettingsController < SignedInApplicationController
  include Tabbable
  using RefinedString
  using RefinedInteger

  before_action :require_write_access!, only: %i[update edit]
  before_action :set_train, only: %i[index update edit]
  before_action :set_notification_setting, only: %i[update edit]
  around_action :set_time_zone

  def index
    if @train.send_notifications?
      @notification_settings = @train.notification_settings.where(kind: NotificationSetting.kinds.values)
    end

    set_train_config_tabs
  end

  def edit
    @setting = NotificationSettingsComponent::NotificationSettingComponent.new(@app, @train, @notification_setting)
    set_train_config_tabs
  end

  def update
    head :forbidden and return unless @train.send_notifications?

    if @notification_setting.update(parsed_notif_setting_params)
      redirect_to app_train_notification_settings_path(@app, @train), notice: "Notification setting was updated"
    else
      redirect_to app_train_notification_settings_path(@app, @train), flash: {error: "There was an error: #{@notification_setting.errors.full_messages.to_sentence}"}
    end
  end

  private

  def set_notification_setting
    @notification_setting = @train.notification_settings.find(params[:id])
  end

  def set_train
    @train = @app.trains.friendly.find(params[:train_id])
  end

  def notif_setting_params
    params.require(:notification_setting).permit(
      :active,
      notification_channels: []
    )
  end

  def parsed_notif_setting_params
    notif_setting_params.merge(notification_channels: notification_channels)
  end

  def notification_channels
    notif_setting_params[:notification_channels]&.compact_blank&.map(&:safe_json_parse)
  end
end
