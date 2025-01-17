# frozen_string_literal: true

class LiveRelease::ProdRelease::PreviousSubmissionComponent < LiveRelease::ProdRelease::SubmissionComponent
  def status
    super.merge(kind: :status_pill)
  end
end
