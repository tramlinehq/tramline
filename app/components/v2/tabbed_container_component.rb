class V2::TabbedContainerComponent < V2::BaseComponent
  renders_one :back_button, V2::BackButtonComponent
  renders_many :tabs

  TAB_STYLE = "inline-flex items-center justify-center p-4 border-b-2 border-transparent rounded-t-lg hover:text-main-600 hover:border-main-300 dark:hover:text-main-300 group"
  SELECTED_TAB_STYLE = "inline-flex items-center justify-center p-4 text-blue-600 border-b-2 border-blue-600 rounded-t-lg active dark:text-blue-500 dark:border-blue-500 group"

  def initialize(title:, turbo_frame:, tab_config: [])
    raise ArgumentError, "tab_config must be an array" unless tab_config.is_a?(Array)
    raise ArgumentError, "tab_config must be an array of arrays" unless tab_config.all? { _1.length == 4 }

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
