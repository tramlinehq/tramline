# == Schema Information
#
# Table name: releases_pull_requests
#
#  id                 :uuid             not null, primary key
#  base_ref           :string           not null, indexed => [train_group_run_id, head_ref]
#  body               :text
#  closed_at          :datetime
#  head_ref           :string           not null, indexed => [train_group_run_id, base_ref]
#  number             :bigint           not null, indexed
#  opened_at          :datetime         not null
#  phase              :string           not null, indexed
#  source             :string           not null, indexed
#  state              :string           not null, indexed
#  title              :string           not null
#  url                :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  source_id          :string           not null, indexed
#  train_group_run_id :uuid             indexed => [head_ref, base_ref]
#  train_run_id       :uuid
#
class Releases::PullRequest < ApplicationRecord
  class UnsupportedPullRequestSource < StandardError; end

  self.table_name = "releases_pull_requests"

  belongs_to :train_run, class_name: "Releases::Train::Run", optional: true
  belongs_to :train_group_run, class_name: "Releases::TrainGroup::Run"

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
    github: "github",
    gitlab: "gitlab"
  }

  def update_or_insert!(response)
    attributes =
      case repository_source_name
      when "github"
        attributes_for_github(response)
      when "gitlab"
        attributes_for_gitlab(response)
      else
        raise UnsupportedPullRequestSource
      end

    Releases::PullRequest
      .upsert(generic_attributes.merge(attributes), unique_by: [:train_group_run_id, :head_ref, :base_ref])
      .rows
      .first
      .first
      .then { |id| Releases::PullRequest.find_by(id: id) }
  end

  def close!
    self.closed_at = Time.current
    self.state = Releases::PullRequest.states[:closed]
    save!
  end

  private

  def attributes_for_github(response)
    {
      source: Releases::PullRequest.sources[:github],
      source_id: response[:id],
      number: response[:number],
      title: response[:title],
      body: response[:body],
      url: response[:html_url],
      state: response[:state],
      head_ref: response[:head][:ref],
      base_ref: response[:base][:ref],
      opened_at: response[:created_at]
    }
  end

  def attributes_for_gitlab(response)
    {
      source: Releases::PullRequest.sources[:gitlab],
      source_id: response["id"],
      number: response["iid"],
      title: response["title"],
      body: response["description"],
      url: response["web_url"],
      state: gitlab_state(response["state"]),
      head_ref: response["sha"],
      base_ref: response["sha"], # TODO: this is a temporary fix, we should fetch the correct sha from GitLab and fill this
      opened_at: response["created_at"]
    }
  end

  def generic_attributes
    {
      train_run_id: train_run&.id,
      train_group_run_id: train_group_run&.id,
      phase: phase
    }
  end

  def gitlab_state(response_state)
    case response_state
    when "opened", "locked"
      Releases::PullRequest.states[:open]
    when "merged", "closed"
      Releases::PullRequest.states[:closed]
    else
      Releases::PullRequest.states[:closed]
    end
  end

  def repository_source_name
    return train_run.train.vcs_provider.to_s if train_run
    train_group_run.train_group.vcs_provider.to_s
  end
end
