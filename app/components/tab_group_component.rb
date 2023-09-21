class TabGroupComponent < ViewComponent::Base
  renders_one :tab_heading
  renders_many :tabs

  def initialize(release:, groups:)
    @release = release
    @groups = groups
  end

  def tab_headings
    @groups.each_with_index.map do |group, idx|
      {
        selected: idx == 0,
        name: group
      }
    end
  end
end
