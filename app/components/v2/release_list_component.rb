# frozen_string_literal: true

class V2::ReleaseListComponent < V2::BaseComponent
  def initialize(releases:)
    @releases = releases
  end

  attr_reader :releases
end
