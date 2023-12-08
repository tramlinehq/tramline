# frozen_string_literal: true

class V2::TabbedContainerComponent < V2::BaseComponent
  renders_many :tabs

  TAB_STYLE = "inline-block p-4 border-b-2 rounded-t-lg hover:text-gray-600 hover:border-gray-300 dark:hover:text-gray-300"
  SELECTED_TAB_STYLE = "inline-block p-4 text-blue-600 border-b-2 border-blue-600 rounded-t-lg active dark:text-blue-500 dark:border-blue-500"

  def initialize(title:, tab_config: [], turbo_frame:)
    raise ArgumentError, "tab_config must be an array" unless tab_config.is_a?(Array)
    raise ArgumentError, "tab_config must be an array of arrays" unless tab_config.all? { _1.length == 3 }

    @title = title
    @tab_config = tab_config
    @turbo_frame = turbo_frame
  end

  attr_reader :title, :tab_config

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
