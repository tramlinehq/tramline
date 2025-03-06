# frozen_string_literal: true

class ConvertChangelogCommitsToCommitObjects < ActiveRecord::Migration[7.0]
  def up
    commits_processed = 0
    ActiveRecord::Base.transaction do
      ReleaseChangelog.pluck(:id, :release_id, :commits).each do |changelog_id, release_id, changelog_commits|
        next if changelog_commits.blank?
        changelog_commits.each do |commit_data|
          begin
            commit_hash = commit_data["commit_hash"] || commit_data["sha"]
            # in production, no commit should have nil timestamps, but in case it does, use epoch
            timestamp = Time.zone.parse(commit_data["author_timestamp"] || commit_data["timestamp"] || Time.at(0).to_s)
            # sometimes for bots, the email + login are both not available, so hopefully we have the name
            author_email = commit_data["author_email"] || commit_data["author_login"] || commit_data["author_name"] || "unknown"

            # Skip if commit already exists for this changelog
            next if Commit.exists?(commit_hash: commit_hash, release_changelog_id: changelog_id)

            # Create Commit object from JSONB data
            commit = Commit.new(
              author_email: author_email,
              author_login: commit_data["author_login"],
              author_name: commit_data["author_name"],
              commit_hash: commit_hash,
              message: commit_data["message"],
              parents: commit_data["parents"],
              timestamp: timestamp,
              url: commit_data["url"],
              release_id: release_id,
              release_changelog_id: changelog_id
            )

            commit.save!
            commits_processed += 1
          rescue ActiveRecord::RecordInvalid
            puts "Logging commit #{commit_hash} for changelog #{changelog_id} because it is invalid"
            raise
          end
        end

        puts "processed a total of #{commits_processed} commits"
      end
    end

    original_size = ReleaseChangelog.select("SUM(jsonb_array_length(commits)) as tc")[0].tc
    new_size = ReleaseChangelog.joins(:commits).count(:commits)

    if original_size != new_size
      puts "original size: #{original_size}"
      puts "new size: #{new_size}"
      puts "commits processed: #{commits_processed}"
      raise ActiveRecord::RecordInvalid
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

