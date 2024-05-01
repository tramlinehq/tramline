class V2::SimpleTabComponent < V2::BaseComponent
  renders_one :tab_heading
  renders_many :tabs

  def initialize(groups:, title: nil)
    @title = title
    @groups = groups
  end

  attr_reader :title

  def tab_headings
    @groups.each_with_index.map do |group, idx|
      {
        selected: idx == 0,
        name: group
      }
    end
  end
end
