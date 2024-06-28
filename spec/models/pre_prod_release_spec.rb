# frozen_string_literal: true

require "rails_helper"

describe PreProdRelease do
  describe "#trigger_submissions!" do
    let(:pre_prod_release) { create(:pre_prod_release) }
    let(:workflow_run) { create(:workflow_run, triggering_release: pre_prod_release) }

    it "triggers the first submission" do
      build = create(:build, workflow_run:)
      pre_prod_release.trigger_submissions!
      expect(pre_prod_release.store_submissions.count).to eq(1)
      expect(pre_prod_release.store_submissions.sole.build).to eq(build)
    end
  end
end
