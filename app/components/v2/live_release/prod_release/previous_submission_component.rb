# frozen_string_literal: true

class V2::LiveRelease::ProdRelease::PreviousSubmissionComponent < V2::LiveRelease::ProdRelease::SubmissionComponent
  def status
    super.merge(kind: :status_pill)
  end
end
