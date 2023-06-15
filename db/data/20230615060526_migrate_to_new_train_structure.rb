# frozen_string_literal: true

class MigrateToNewTrainStructure < ActiveRecord::Migration[7.0]
  class MigrationIntegrityFailed < StandardError; end

  def up
    ActiveRecord::Base.transaction do
      ReleasePlatform.all.each do |platform|
        # using attributes because some direct AR methods might have changed or delegated back up in code
        attributes = OpenStruct.new platform.attributes
        name = attributes.name
        description = attributes.description
        status = attributes.status
        branching_strategy = attributes.branching_strategy
        release_branch = attributes.release_branch
        release_backmerge_branch = attributes.release_backmerge_branch
        working_branch = attributes.working_branch
        vcs_webhook_id = attributes.vcs_webhook_id
        slug = attributes.slug
        version_seeded_with = attributes.version_seeded_with
        version_current = attributes.version_current
        app_id = attributes.app_id

        train = Train.new(
          app_id:,
          name:,
          description:,
          status:,
          branching_strategy:,
          release_branch:,
          release_backmerge_branch:,
          working_branch:,
          vcs_webhook_id:,
          slug:,
          version_seeded_with:,
          version_current:
        )
        train.in_data_migration_mode = true
        train.save!

        platform.update!(train:)

        CommitListener.where(release_platform_id: platform.id).each do |listener|
          listener.update!(train:)
        end

        platform.runs.each do |run|
          # using attributes because some direct AR methods might have changed or delegated back up in code
          attributes = OpenStruct.new run.attributes
          branch_name = attributes.branch_name
          status = attributes.status
          original_release_version = attributes.original_release_version
          release_version = attributes.release_version
          scheduled_at = attributes.scheduled_at
          completed_at = attributes.completed_at
          stopped_at = attributes.stopped_at

          release = Release.new(
            train:,
            branch_name:,
            status:,
            original_release_version:,
            release_version:,
            scheduled_at:,
            completed_at:,
            stopped_at:
          )
          release.in_data_migration_mode = true
          release.save!

          run.update!(release:)

          Commit.where(release_platform_run_id: run.id).each do |commit|
            commit.update!(release:)
          end

          PullRequest.where(release_platform_run_id: run.id).each do |pr|
            pr.update!(release:)
          end

          ReleaseMetadata.find_by(release_platform_run_id: run.id).update!(release:)
        end
      end

      assertions = [
        ReleasePlatform.all.size == Train.all.size,
        ReleasePlatformRun.all.size == Release.all.size,
        Commit.where(release_id: nil).size == 0,
        PullRequest.where(release_id: nil).size == 0,
        CommitListener.where(train_id: nil).size == 0,
        ReleaseMetadata.where(release_id: nil).size == 0
      ]

      raise MigrationIntegrityFailed, "index: #{assertions.index(false)}" unless assertions.all?
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
