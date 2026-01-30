# frozen_string_literal: true

class AppListComponent < BaseComponent
  def initialize(apps: [])
    @apps = Array(apps)
  end

  attr_reader :apps
end
