require "rails_helper"

describe WebhookHandlers::Push do
  let(:train) { create(:releases_train) }
  let(:payload) { JSON.parse(File.read("spec/fixtures/github/push.json")) }
  let(:handler) { described_class.new(train, payload) }

  describe "#process" do
    it "returns accepted when release not present" do
      expect(handler.process.status).to be_eql(:accepted)
    end
  end
end
