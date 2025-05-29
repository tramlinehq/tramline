# frozen_string_literal: true

class UpdatePullRequestsToNormalizeKindsAndPhases < ActiveRecord::Migration[7.2]
  def up
    return
    PullRequest.transaction do
      PullRequest.find_each do |pull_request|
        if pull_request.phase == "version_bump"
          pull_request.update!(phase: "pre_release", kind: "version_bump")
        elsif pull_request.phase == "ongoing"
          pull_request.update!(phase: "mid_release", kind: "back_merge")
        elsif pull_request.phase == "mid_release"
          pull_request.update!(phase: "mid_release", kind: "stability")
        elsif pull_request.phase == "post_release"
          pull_request.update!(phase: "post_release", kind: "back_merge")
        elsif pull_request.phase == "pre_release"
          pull_request.update!(phase: "pre_release", kind: "forward_merge")
        else
          raise "Unknown phase: #{pull_request.phase}"
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
