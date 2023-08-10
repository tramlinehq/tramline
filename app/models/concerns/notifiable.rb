module Notifiable
  def notification_channel_id
    return if notification_channel.blank?
    notification_channel["id"]
  end

  def notification_channel_name
    return if notification_channel.blank?
    notification_channel["name"]
  end
end
