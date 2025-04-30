# frozen_string_literal: true

module AppHelper
  def release_specific_channel_pattern(app)
    platform = app.cross_platform? ? "" : "-#{app.platform}"
    channel_pattern = "release-#{app.name}#{platform}".downcase.gsub(/\W/, "-")
    "#{channel_pattern}-{version}"
  end
end
