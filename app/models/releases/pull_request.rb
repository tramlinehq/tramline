class Releases::PullRequest < ApplicationRecord
  class UnsupportedPullRequestSource < StandardError; end

  self.table_name = "releases_pull_requests"

  belongs_to :train_run, class_name: "Releases::Train::Run"

  enum phase: {
    pre_release: "pre_release",
    ongoing: "ongoing",
    post_release: "post_release"
  }

  enum state: {
    open: "open",
    closed: "closed"
  }

  enum source: {
    github: "github"
  }

  def update_or_insert!(response)
    case repository_source_name
    when "github"
      update_or_insert_for_github!(response)
    else
      raise UnsupportedPullRequestSource.new
    end
  end

  def update_or_insert_for_github!(response)
    self.source = Releases::PullRequest.sources[:github]
    self.source_id = response[:id]
    self.number = response[:number]
    self.title = response[:title]
    self.body = response[:body]
    self.url = response[:html_url]
    self.state = response[:state]
    self.head_ref = response[:head][:ref]
    self.base_ref = response[:base][:ref]
    self.opened_at = response[:created_at]

    Releases::PullRequest.upsert(attributes, unique_by: [:train_run_id, :head_ref, :base_ref])
  end

  def close!
    self.closed_at = Time.current
    self.status = Releases::PullRequest.states[:closed]
    save!
  end

  def repository_source_name
    train_run.train.vcs_provider.to_s
  end
end
