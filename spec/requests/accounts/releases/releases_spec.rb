require 'rails_helper'

RSpec.describe 'Accounts::Releases::Releases', type: :request do
  describe 'GET /show' do
    let(:release) { FactoryBot.create(:releases_train_run) }
    let(:organization) { FactoryBot.create(:organization) }
    let(:user) { FactoryBot.create(:accounts_user, confirmed_at: Time.now, organizations: [organization]) }

    it 'returns success code' do
      sign_in user
      get accounts_releases_release_path(release.id)
      expect(response).to have_http_status(200)
    end
  end
end
