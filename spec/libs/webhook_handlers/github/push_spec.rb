require "rails_helper"

RSpec.describe WebhookHandlers::Github::Push do
  let(:train) { FactoryBot.create(:releases_train) }
  let(:payload) { JSON.parse(File.read("spec/fixtures/github/push.json")) }
  let(:handler) { WebhookHandlers::Github::Push.new(train, payload) }

  describe "#process" do
    it "returns unprocessable_entity when release not present" do
      expect(handler.process.status).to be_eql(:unprocessable_entity)
    end
  end
end
