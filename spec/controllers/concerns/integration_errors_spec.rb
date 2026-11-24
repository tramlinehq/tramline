require "rails_helper"

describe IntegrationErrors do
  controller(SignedInApplicationController) do
    def index = head(:ok)

    def create = head(:ok)
  end

  let(:app) { create(:app, :ios) }
  let(:user) { app.organization.owner }
  let(:agreement_error) {
    Installations::Apple::AppStoreConnect::Error.new(
      {"error" => {"resource" => "app_store_connect_api", "code" => "agreement_missing", "message" => "A required Apple agreement is missing or has expired."}}
    )
  }
  let(:server_error) { Installations::Error.new("The server failed to fulfill the request", reason: :server_error) }

  before do
    sign_in user.email_authentication
    allow(Sentry).to receive(:capture_exception)
    allow(controller).to receive(:index).and_raise(agreement_error)
    allow(controller).to receive(:create).and_raise(server_error)
  end

  it "sends the user back with the provider's error in a flash" do
    request.headers["Referer"] = "http://test.host/apps"

    get :index

    expect(response).to redirect_to("http://test.host/apps")
    expect(flash[:error]).to eq("App Store Connect returned an error: A required Apple agreement is missing or has expired.")
  end

  it "does not send a page that failed to load back to itself" do
    request.headers["Referer"] = "http://test.host/signed_in_application?page=2"

    get :index, params: {app_id: app.slug}

    expect(response).to redirect_to(app_path(app))
  end

  it "falls back to the root when there is nowhere else to go" do
    get :index

    expect(response).to redirect_to(root_path)
  end

  it "ignores a referer on another host" do
    request.headers["Referer"] = "https://example.com/elsewhere"

    get :index

    expect(response).to redirect_to(root_path)
  end

  it "returns a failed form submission to the page it came from" do
    request.headers["Referer"] = "http://test.host/signed_in_application"

    post :create

    expect(response).to redirect_to("http://test.host/signed_in_application")
    expect(flash[:error]).to eq("An integration returned an error: The server failed to fulfill the request")
  end

  it "shows a generic message when the error carries none" do
    allow(controller).to receive(:index).and_raise(Installations::Apple::AppStoreConnect::Error.new)

    get :index

    expect(flash[:error]).to eq("App Store Connect returned an error Tramline could not read. Check that the integration is connected correctly and try again.")
  end

  it "reports the error as a warning" do
    get :index

    expect(Sentry).to have_received(:capture_exception).with(an_instance_of(Installations::Apple::AppStoreConnect::Error), level: :warning)
  end
end
