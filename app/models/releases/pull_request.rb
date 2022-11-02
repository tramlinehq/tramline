# == Schema Information
#
# Table name: releases_pull_requests
#
#  id           :uuid             not null, primary key
#  train_run_id :uuid             not null
#  number       :bigint           not null
#  source_id    :string           not null
#  url          :string
#  title        :string           not null
#  body         :text
#  state        :string           not null
#  phase        :string           not null
#  source       :string           not null
#  head_ref     :string           not null
#  base_ref     :string           not null
#  opened_at    :datetime         not null
#  closed_at    :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
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
    attributes =
      case repository_source_name
      when "github"
        attributes_for_github(response)
      else
        raise UnsupportedPullRequestSource
      end

    Releases::PullRequest
      .upsert(generic_attributes.merge(attributes), unique_by: [:train_run_id, :head_ref, :base_ref])
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

  def generic_attributes
    {
      train_run_id: train_run.id,
      phase: phase
    }
  end

  def repository_source_name
    train_run.train.vcs_provider.to_s
  end
end
