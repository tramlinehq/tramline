class ReleasePlatformRuns::CreateTagJob < ApplicationJob
  queue_as :high

  def perform(platform_run_id, tag_name)
    run = ReleasePlatformRun.find(platform_run_id)

    begin
      run.update(tag_name:)
      run.create_tag!(tag_name)
    rescue Installations::Errors::TagReferenceAlreadyExists
      self.class.perform_later(release_platform_run_id, run.unique_tag_name)
    end
  end
end
