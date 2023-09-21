class ReleaseSummaryComponent < ViewComponent::Base
  renders_one :tab_heading
  renders_many :tabs

  def initialize(release:)
    @release = release
  end

  def tab_headings
    [{
      id: "overall-tab",
      selected: true,
      name: "Overall"
    },
      {
        id: "fixes-tab",
        selected: false,
        name: "Versions sent to store"
      },
      {
        id: "review-tab",
        selected: true,
        name: "Step summary"
      },
      {
        id: "pr-tab",
        selected: true,
        name: "Pull requests"
      }]
  end
end
