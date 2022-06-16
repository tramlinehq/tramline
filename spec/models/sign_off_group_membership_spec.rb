require 'rails_helper'

RSpec.describe SignOffGroupMembership, type: :model do
  it 'has a valid factory' do
    expect(FactoryBot.build(:sign_off_group_membership)).to be_valid
  end
end
