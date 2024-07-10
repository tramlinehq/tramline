# frozen_string_literal: true

class V2::LiveRelease::SubmissionConfigComponent < V2::BaseComponent
  def initialize(submission)
    @submission = submission
  end
end
