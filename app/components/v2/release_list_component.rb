# frozen_string_literal: true

class V2::ReleaseListComponent < V2::BaseComponent
  def initialize(devops_report:, releases:)
    @releases = releases
    @devops_report = devops_report
  end

  attr_reader :releases, :devops_report
end
