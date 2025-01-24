class OneOff::BackfillAuthorLogins < ApplicationJob
  queue_as :low

  def perform(release_id)
    release = Release.find(release_id)
    vcs_provider = release.train.vcs_provider
    return unless vcs_provider.to_s == "github"

    Commit.transaction do
      release.all_commits.each do |commit|
        next if commit.author_login.present?
        commit_info = vcs_provider.installation.client.commit(vcs_provider.code_repository_name, commit.commit_hash)
        commit.update! author_login: commit_info.author.login
      rescue => e
        Rails.logger.error(e)
        next
      end
    end
  end
end
