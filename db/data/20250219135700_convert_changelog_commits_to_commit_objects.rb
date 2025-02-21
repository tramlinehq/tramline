# frozen_string_literal: true

class ConvertChangelogCommitsToCommitObjects < ActiveRecord::Migration[7.0]
  def up
    ActiveRecord::Base.transaction do
      ReleaseChangelog.find_each do |changelog|
        next if changelog.commits.blank?

        changelog.commits.each do |commit_data|
          # Skip if commit already exists for this release
          next if Commit.exists?(commit_hash: commit_data["commit_hash"], release_id: changelog.release_id)

          # Create Commit object from JSONB data
          commit = Commit.new(
            author_email: commit_data["author_email"],
            author_login: commit_data["author_login"],
            author_name: commit_data["author_name"],
            commit_hash: commit_data["commit_hash"],
            message: commit_data["message"],
            parents: commit_data["parents"],
            timestamp: commit_data["timestamp"],
            url: commit_data["url"],
            release_id: changelog.release_id
          )

          commit.save!
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
