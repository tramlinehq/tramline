class V2::ReleaseComponent < ViewComponent::Base
  renders_one :back_button, V2::BackButtonComponent
  renders_many :sub_actions
  renders_many :tabs, ->(**args) { V2::LiveRelease::StepComponent.new(frame: @frame, **args) }

  SELECTED_TAB_STYLE = "active text-main bg-white border-l-3"

  def initialize(release, title:, turbo_frame:, tab_config: [], error_resource: nil)
    raise ArgumentError, "tab_config must be a Hash" unless tab_config.is_a?(Hash)

    @release = release
    @title = title
    @tab_config = tab_config
    @turbo_frame = turbo_frame
    @error_resource = error_resource
  end

  attr_reader :title, :tab_config, :error_resource, :release

  def frame = @turbo_frame

  def sorted_sections
    tab_config.to_h do |s, configs|
      [s, configs.sort_by { _1[0] }]
    end
  end

  def status
    "bg-#{["green", "amber"].sample}-200 text-green-800"
  end

  def active_style(tab_path)
    SELECTED_TAB_STYLE if current_page?(tab_path)
  end
end
