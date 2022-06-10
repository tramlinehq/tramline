require 'rails_helper'

RSpec.describe WebhookHandlers::Github::WorkflowRun do
  let(:train) { Releases::Train.new }
  let(:payload) { JSON.parse(File.read('spec/fixtures/github/workflow_run.json')) }
  let(:handler) { WebhookHandlers::Github::WorkflowRun.new(train, payload.with_indifferent_access) }

  describe '#process' do
    it 'returns success' do
      expect(handler.process.status).to be_eql(:accepted)
    end
  end
end
