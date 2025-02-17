# frozen_string_literal: true

class VerticalTabComponent < BaseComponent
  renders_many :tabs

  TAB_STYLE = "flex flex-row items-center justify-between w-full rounded hover:text-main-900 hover:bg-main-100 px-2"
  SELECTED_TAB_STYLE = "flex flex-row items-center justify-between w-full rounded hover:text-main-900 hover:bg-main-100 active text-main bg-main-100 border-l-2 border-main-400 px-2"

  def initialize(turbo_frame:, sidebar_header:, tab_config: [], error_resource: nil)
    raise ArgumentError, "tab_config must be an array" unless tab_config.is_a?(Array)
    raise ArgumentError, "tab_config must be an array of arrays" unless tab_config.all? { _1.length == 4 }

    @tab_config = tab_config
    @turbo_frame = turbo_frame
    @error_resource = error_resource
    @sidebar_header = sidebar_header
  end

  attr_reader :tab_config, :error_resource, :sidebar_header

  def frame = @turbo_frame

  def sorted_configs
    tab_config.sort_by { |config| config[0] }
  end

  def style(tab_path)
    if current_page?(tab_path)
      SELECTED_TAB_STYLE
    else
      TAB_STYLE
    end
  end
end
