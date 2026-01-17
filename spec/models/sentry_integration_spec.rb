require "rails_helper"

describe SentryIntegration do
  let(:app) { create(:app, :android) }
  let(:integration) { create(:integration, :with_sentry, integrable: app) }
  let(:sentry_integration) { integration.providable }
  let(:api_instance) { instance_spy(Installations::Sentry::Api) }

  before do
    allow(Installations::Sentry::Api).to receive(:new).and_return(api_instance)
    allow_any_instance_of(described_class).to receive(:correct_key).and_return(true)
  end

  it "has a valid factory" do
    expect(sentry_integration).to be_valid
  end

  describe "#installation" do
    it "returns an API instance with the access token" do
      sentry_integration.installation
      expect(Installations::Sentry::Api).to have_received(:new).with(sentry_integration.access_token)
    end

    it "returns the API instance" do
      expect(sentry_integration.installation).to eq(api_instance)
    end
  end

  describe "#list_organizations" do
    let(:organizations) do
      [
        {name: "Org 1", id: "123", slug: "org-1"},
        {name: "Org 2", id: "456", slug: "org-2"}
      ]
    end

    before do
      allow(api_instance).to receive(:list_organizations).and_return(organizations)
    end

    it "calls the API list_organizations method with transformations" do
      sentry_integration.list_organizations

      expect(api_instance).to have_received(:list_organizations).with(
        SentryIntegration::ORGANIZATIONS_TRANSFORMATIONS
      )
    end

    it "returns the list of organizations" do
      expect(sentry_integration.list_organizations).to eq(organizations)
    end
  end

  describe "#list_projects" do
    let(:organizations) do
      [{name: "Org 1", id: "123", slug: "org-1"}]
    end
    let(:projects) do
      [
        {name: "Project 1", id: "1", slug: "project-1", platform: "android"},
        {name: "Project 2", id: "2", slug: "project-2", platform: "ios"}
      ]
    end

    before do
      allow(api_instance).to receive_messages(
        list_organizations: organizations,
        list_projects: projects
      )
    end

    it "calls the API list_projects for each organization" do
      sentry_integration.list_projects

      expect(api_instance).to have_received(:list_projects).with(
        "org-1",
        SentryIntegration::PROJECTS_TRANSFORMATIONS
      )
    end

    it "returns the flattened list of projects" do
      expect(sentry_integration.list_projects).to eq(projects)
    end

    it "caches the result" do
      sentry_integration.list_projects
      sentry_integration.list_projects

      expect(api_instance).to have_received(:list_projects).once
    end
  end

  describe "#find_release" do
    let(:version) { "1.0.0" }
    let(:build_number) { "100" }
    let(:bundle_identifier) { "com.example.app" }
    let(:platform) { "android" }
    let(:organization_slug) { "test-org" }
    let(:project_slug) { "test-project" }
    let(:environment) { "production" }

    before do
      sentry_integration.update!(
        android_config: {
          project: {id: "123", slug: project_slug, name: "Test Project"},
          environment: environment,
          organization_slug: organization_slug
        }
      )
      allow(api_instance).to receive(:find_release)
      allow(sentry_integration.integrable).to receive(:bundle_identifier).and_return(bundle_identifier)
    end

    it "calls the API find_release method with correct arguments" do
      sentry_integration.find_release(platform, version, build_number)

      expect(api_instance).to have_received(:find_release).with(
        organization_slug,
        project_slug,
        environment,
        bundle_identifier,
        version,
        build_number,
        SentryIntegration::RELEASE_TRANSFORMATIONS
      )
    end

    it "constructs the release identifier with bundle ID, version, and build number" do
      # The API layer constructs: bundle_id@version+build_number
      sentry_integration.find_release(platform, version, build_number)

      expect(api_instance).to have_received(:find_release)
    end
  end

  describe "#dashboard_url" do
    let(:platform) { "android" }
    let(:release_id) { "com.example.app@1.0.0+100" }
    let(:organization_slug) { "test-org" }
    let(:project_slug) { "test-project" }

    before do
      sentry_integration.update!(
        android_config: {
          project: {id: "123", slug: project_slug, name: "Test Project"},
          environment: "production",
          organization_slug: organization_slug
        }
      )
    end

    context "with a release_id" do
      it "returns the release-specific URL" do
        url = sentry_integration.dashboard_url(platform: platform, release_id: release_id)

        expect(url).to eq("https://sentry.io/organizations/#{organization_slug}/projects/#{project_slug}/releases/#{release_id}/")
      end
    end

    context "without a release_id" do
      it "returns the project overview URL" do
        url = sentry_integration.dashboard_url(platform: platform, release_id: nil)

        expect(url).to eq("https://sentry.io/organizations/#{organization_slug}/projects/#{project_slug}/")
      end
    end

    context "when project config is missing" do
      before do
        sentry_integration.update!(android_config: nil)
      end

      it "returns nil" do
        expect(sentry_integration.dashboard_url(platform: platform, release_id: release_id)).to be_nil
      end
    end
  end

  describe "#project" do
    let(:ios_project) { {id: "1", slug: "ios-proj", name: "iOS Project"} }
    let(:android_project) { {id: "2", slug: "android-proj", name: "Android Project"} }

    before do
      sentry_integration.update!(
        ios_config: {project: ios_project, environment: "production", organization_slug: "org"},
        android_config: {project: android_project, environment: "production", organization_slug: "org"}
      )
    end

    it "returns the iOS project config" do
      expect(sentry_integration.project("ios")).to eq(ios_project)
    end

    it "returns the Android project config" do
      expect(sentry_integration.project("android")).to eq(android_project)
    end

    it "raises an error for invalid platform" do
      expect { sentry_integration.project("invalid") }.to raise_error(ArgumentError)
    end
  end

  describe "#environment" do
    before do
      sentry_integration.update!(
        ios_config: {project: {id: "1", slug: "proj"}, environment: "production", organization_slug: "org"},
        android_config: {project: {id: "2", slug: "proj"}, environment: "staging", organization_slug: "org"}
      )
    end

    it "returns the iOS environment" do
      expect(sentry_integration.environment("ios")).to eq("production")
    end

    it "returns the Android environment" do
      expect(sentry_integration.environment("android")).to eq("staging")
    end

    it "raises an error for invalid platform" do
      expect { sentry_integration.environment("invalid") }.to raise_error(ArgumentError)
    end
  end

  describe "#connection_data" do
    let(:organizations) do
      [
        {name: "Org 1", slug: "org-1"},
        {name: "Org 2", slug: "org-2"}
      ]
    end

    before do
      allow(sentry_integration.integration).to receive(:metadata).and_return(organizations)
    end

    it "returns formatted organization data" do
      expect(sentry_integration.connection_data).to eq("Organization(s): Org 1 (org-1), Org 2 (org-2)")
    end

    context "when metadata is nil" do
      before do
        allow(sentry_integration.integration).to receive(:metadata).and_return(nil)
      end

      it "returns nil" do
        expect(sentry_integration.connection_data).to be_nil
      end
    end
  end

  describe "#to_s" do
    it "returns 'sentry'" do
      expect(sentry_integration.to_s).to eq("sentry")
    end
  end

  describe "#creatable?" do
    it "returns true" do
      expect(sentry_integration.creatable?).to be true
    end
  end

  describe "#connectable?" do
    it "returns false" do
      expect(sentry_integration.connectable?).to be false
    end
  end

  describe "#store?" do
    it "returns false" do
      expect(sentry_integration.store?).to be false
    end
  end

  describe "#further_setup?" do
    it "returns true" do
      expect(sentry_integration.further_setup?).to be true
    end
  end

  describe "#setup" do
    let(:projects) { [{name: "Project 1", id: "1", slug: "project-1"}] }

    before do
      allow(sentry_integration).to receive(:list_projects).and_return(projects)
    end

    it "returns the list of projects" do
      expect(sentry_integration.setup).to eq(projects)
    end
  end

  describe "validations" do
    it "validates presence of access_token" do
      sentry_integration.access_token = nil
      expect(sentry_integration).not_to be_valid
      expect(sentry_integration.errors[:access_token]).to include("can't be blank")
    end

    context "when creating" do
      let(:new_integration) { build(:sentry_integration, access_token: "test_token") }

      before do
        allow_any_instance_of(described_class).to receive(:correct_key).and_call_original
        allow(api_instance).to receive(:list_organizations).and_return(nil)
      end

      it "validates that the token can access organizations" do
        new_integration.save

        expect(new_integration.errors[:access_token]).to include("could not find any orgs listed for this token!")
      end
    end
  end

  describe "encryption" do
    it "encrypts the access_token" do
      expect(sentry_integration.access_token).not_to be_nil
      expect(sentry_integration.read_attribute_before_type_cast(:access_token)).not_to eq(sentry_integration.access_token)
    end
  end

  describe "#metadata" do
    let(:organizations) { [{name: "Org", id: "123", slug: "org"}] }

    before do
      allow(api_instance).to receive(:list_organizations).and_return(organizations)
    end

    it "returns the list of organizations" do
      expect(sentry_integration.metadata).to eq(organizations)
    end
  end
end
