class Coordinators::VersionBumpJob < ApplicationJob
  queue_as :high

  def perform(release_id)
    release = Release.find(release_id)
    Triggers::VersionBump.call(release).value!
  end
end
