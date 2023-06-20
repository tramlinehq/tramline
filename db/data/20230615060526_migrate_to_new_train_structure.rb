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
        slug = attributes.slug
        version_seeded_with = attributes.version_seeded_with
        version_current = attributes.version_current
        app_id = attributes.app_id
        updated_at = attributes.updated_at
        created_at = attributes.created_at

        train = Train.new(
          app_id:,
          name:,
          description:,
          status:,
          branching_strategy:,
          release_branch:,
          release_backmerge_branch:,
          working_branch:,
          vcs_webhook_id: nil,
          slug:,
          version_seeded_with:,
          version_current:,
          created_at:,
          updated_at:
        )
        train.in_data_migration_mode = true
        train.save!

        platform.update!(train:, platform: platform.app.platform)

        platform.release_platform_runs.each do |run|
          # using attributes because some direct AR methods might have changed or delegated back up in code
          attributes = OpenStruct.new run.attributes
          branch_name = attributes.branch_name
          status = attributes.status
          original_release_version = attributes.original_release_version
          release_version = attributes.release_version
          scheduled_at = attributes.scheduled_at
          completed_at = attributes.completed_at
          stopped_at = attributes.stopped_at
          updated_at = attributes.updated_at
          created_at = attributes.created_at

          release = Release.new(
            train:,
            branch_name:,
            status:,
            original_release_version:,
            release_version:,
            scheduled_at:,
            completed_at:,
            stopped_at:,
            created_at:,
            updated_at:
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

          release_metadata = ReleaseMetadata.find_by(release_platform_run_id: run.id)
          if release_metadata
            release_metadata.in_data_migration_mode = true
            release_metadata.update!(release:)
          end
        end
      end

      assertions = [
        ReleasePlatform.all.size == Train.all.size,
        ReleasePlatformRun.all.size == Release.all.size,
        Commit.where(release_id: nil).size == 0,
        PullRequest.where(release_id: nil).size == 0,
        ReleaseMetadata.where(release_id: nil).size == 0
      ]

      raise MigrationIntegrityFailed, "index: #{assertions.index(false)}" unless assertions.all?
    end

    # create webhooks
    Train.running.each do |train|
      train.create_webhook!
    rescue => e
      Rails.logger.debug { "Could not create webhook for train #{train.id}" }
      Rails.logger.error e
    end

    # remove stale/unreliable versions
    PaperTrail::Version.where(item_type: "Releases::CommitListener").delete_all
    PaperTrail::Version.where(item_type: "Releases::PullRequest").delete_all
    PaperTrail::Version.where(item_type: "Releases::Train").delete_all
    PaperTrail::Version.where(item_type: "Releases::Train::Run").delete_all
    PaperTrail::Version.where(item_type: "Releases::Step").delete_all
    PaperTrail::Version.where(item_type: "Releases::Step::Run").delete_all
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
