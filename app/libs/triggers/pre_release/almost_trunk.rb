class Triggers::PreRelease
  class AlmostTrunk
    def self.call(release, release_branch)
      new(release, release_branch).call
    end

    def initialize(release, release_branch)
      @release = release
      @release_branch = release_branch
    end

    def call
      if version_bump_enabled? && !hotfix?
        Triggers::VersionBump.call(release).then { create_default_release_branch }
      else
        create_default_release_branch
      end
    end

    private

    attr_reader :release, :release_branch
    delegate :train, :hotfix?, :hotfix_with_new_branch?, to: :release
    delegate :working_branch, :version_bump_enabled?, to: :train

    def create_default_release_branch
      source =
        if hotfix_with_new_branch?
          {
            ref: release.hotfixed_from.end_ref,
            type: :tag
          }
        elsif version_bump_enabled? && (commit = release.pull_requests.version_bump.first&.merge_commit_sha).present?
          {
            ref: commit,
            type: :commit
          }
        else
          {
            ref: working_branch,
            type: :branch
          }
        end
      stamp_data = {working_branch: source[:ref], release_branch:}
      stamp_type = :release_branch_created
      Triggers::Branch.call(release, source[:ref], release_branch, source[:type], stamp_data, stamp_type)
    end
  end
end
