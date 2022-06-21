require 'rails_helper'

RSpec.describe Releases::CommitListner, type: :model do
  it 'it has valid factoy' do
    expect(FactoryBot.create(:releases_commit_listner)).to be_valid
  end
end
