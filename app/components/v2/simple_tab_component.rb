class V2::SimpleTabComponent < V2::BaseComponent
  renders_one :tab_heading
  renders_many :tabs

  def initialize(groups:, title: nil, selected_tab: -1)
    @title = title
    @groups = groups
    @selected_tab = selected_tab
  end

  attr_reader :title

  def tab_headings
    @groups.each_with_index.map do |group, idx|
      {
        selected: (@selected_tab <= 0) ? idx == 0 : @selected_tab == idx,
        name: group
      }
    end
  end
end
