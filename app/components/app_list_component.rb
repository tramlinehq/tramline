class AppListComponent < ViewComponent::Base
  include ApplicationHelper
  include AssetsHelper

  def initialize(apps:)
    @apps = apps
  end

  def platform_icon(platform)
    inline_svg("#{platform}.svg", classname: "w-8 align-bottom inline-flex")
  end

  def app_icon(platform)
    inline_svg("default_#{platform}.svg", classname: "w-16 border-black-100")
  end

  def apps_by_platform
    @apps.group_by(&:platform)
  end

  def platform_name(platform)
    case platform
    when "android"
      "Android"
    when "ios"
      "iOS"
    else
      "Cross Platform"
    end
  end
end
