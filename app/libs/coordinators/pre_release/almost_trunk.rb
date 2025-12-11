module Coordinators
  module PreRelease
    class AlmostTrunk
      def self.call(release, release_branch)
        new(release, release_branch).call
      end

      def initialize(release, release_branch)
        @release = release
        @release_branch = release_branch
        @pre_release_version_bump_pr = release.pull_requests.pre_release.version_bump_type.first
      end

      def call
        if version_bump_required?
          Triggers::VersionBump.call(release).then { create_default_release_branch }
        else
          create_default_release_branch
        end
      end

      private

      attr_reader :release, :release_branch
      delegate :train, :hotfix?, :hotfix_with_new_branch?, to: :release
      delegate :working_branch, :version_bump_enabled?, :current_version_before_release_branch?, :custom_commit_hash_input?, to: :train

      def create_default_release_branch
        source =
          if hotfix_with_new_branch?
            {
              ref: release.hotfixed_from.end_ref,
              type: :tag
            }
          elsif version_bump_enabled? && (commit = @pre_release_version_bump_pr&.merge_commit_sha).present?
            {
              ref: commit,
              type: :commit
            }
          elsif custom_commit_hash_input? && (commit = release.commit_hash).present?
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

      def version_bump_required?
        version_bump_enabled? &&
          current_version_before_release_branch? &&
          !hotfix? &&
          @pre_release_version_bump_pr.blank?
      end
    end
  end
end
