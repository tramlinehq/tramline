require 'rails_helper'

RSpec.describe TrainSignOffGroup, type: :model do
  it 'has a valid factory' do
    expect(FactoryBot.build(:train_sign_off_group)).to be_valid
  end
end
