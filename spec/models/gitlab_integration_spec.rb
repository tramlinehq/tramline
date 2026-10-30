require "rails_helper"

describe GitlabIntegration do
  let(:app) { create(:app, :android) }
  let(:integration) { create(:integration, integrable: app) }
  let(:gitlab_integration) { create(:gitlab_integration, :without_callbacks_and_validations, integration:) }
  let(:installation) { instance_double(Installations::Gitlab::Api) }

  before do
    allow(gitlab_integration).to receive_messages(installation:)
  end

  describe "#setup_complete?" do
    it "returns true when repository_config is present" do
      gitlab_integration.update!(repository_config: {id: 123, full_name: "tramline/repo", namespace: "tramline"})
      expect(gitlab_integration.setup_complete?).to be true
    end

    it "returns false when repository_config is blank" do
      gitlab_integration.update!(repository_config: nil)
      expect(gitlab_integration.setup_complete?).to be false
    end
  end

  describe "#create_release!" do
    it "calls the GitLab API to create a release" do
      allow(installation).to receive(:create_release!).and_return({"tag_name" => "v1.0.0"})
      result = gitlab_integration.create_release!("v1.0.0", "main", anything, "Release notes")
      expect(installation).to have_received(:create_release!).with(gitlab_integration.code_repository_name, "v1.0.0", "main", "Release notes")
      expect(result).to eq({"tag_name" => "v1.0.0"})
    end

    context "when release creation fails" do
      it "raises an error" do
        allow(installation).to receive(:create_release!).and_raise(Installations::Gitlab::Error.new({"message" => "Release already exists"}))
        expect { gitlab_integration.create_release!("v1.0.0", "main", anything, "Release notes") }.to raise_error(Installations::Gitlab::Error)
      end
    end
  end

  describe "#get_file_content" do
    it "calls the GitLab API to get file content" do
      allow(installation).to receive(:get_file_content).and_return("file content")
      result = gitlab_integration.get_file_content("main", "path/to/file.txt")
      expect(installation).to have_received(:get_file_content).with(gitlab_integration.code_repository_name, "main", "path/to/file.txt")
      expect(result).to eq("file content")
    end

    context "when file doesn't exist" do
      it "returns nil" do
        allow(installation).to receive(:get_file_content).and_return(nil)
        result = gitlab_integration.get_file_content("main", "nonexistent.txt")
        expect(result).to be_nil
      end
    end

    context "when file access fails" do
      it "raises an error" do
        allow(installation).to receive(:get_file_content).and_raise(Installations::Gitlab::Error.new({"message" => "404 File Not Found"}))
        expect { gitlab_integration.get_file_content("main", "protected.txt") }.to raise_error(Installations::Gitlab::Error)
      end
    end
  end

  describe "#update_file!" do
    it "calls the GitLab API to update a file" do
      allow(installation).to receive(:update_file!).and_return(true)
      result = gitlab_integration.update_file!("main", "path/to/file.txt", "new content", "commit message")
      expect(installation).to have_received(:update_file!).with(gitlab_integration.code_repository_name, "main", "path/to/file.txt", "new content", "commit message", author_name: nil, author_email: nil)
      expect(result).to be true
    end

    context "with author information" do
      it "passes author details to update_file!" do
        allow(installation).to receive(:update_file!).and_return(true)
        gitlab_integration.update_file!("main", "path/to/file.txt", "new content", "commit message", author_name: "Test User", author_email: "test@example.com")
        expect(installation).to have_received(:update_file!).with(gitlab_integration.code_repository_name, "main", "path/to/file.txt", "new content", "commit message", author_name: "Test User", author_email: "test@example.com")
      end
    end

    context "when file update fails" do
      it "raises an error" do
        allow(installation).to receive(:update_file!).and_raise(Installations::Gitlab::Error.new({"message" => "File update failed"}))
        expect { gitlab_integration.update_file!("main", "path/to/file.txt", "new content", "commit message") }.to raise_error(Installations::Gitlab::Error)
      end
    end
  end

  describe "#trigger_workflow_run!" do
    it "calls the GitLab API to trigger a pipeline" do
      allow(installation).to receive_messages(
        run_pipeline_with_job!: {ci_ref: "123", ci_link: "http://example.com"},
        list_pipeline_jobs: [{id: "job1", name: "ci_cd_channel", status: "success", stage: "test"}],
        trigger_job!: nil
      )
      gitlab_integration.trigger_workflow_run!("ci_cd_channel", "main", {key: "value"})
      expect(installation).to have_received(:run_pipeline_with_job!).with(gitlab_integration.code_repository_name, "main", {key: "value"}, "ci_cd_channel", nil, GitlabIntegration::WORKFLOW_RUN_TRANSFORMATIONS)
    end

    context "with commit SHA" do
      it "passes commit SHA to run_pipeline_with_job!" do
        allow(installation).to receive(:run_pipeline_with_job!).and_return({ci_ref: "123", ci_link: "http://example.com"})
        gitlab_integration.trigger_workflow_run!("ci_cd_channel", "main", {key: "value"}, "abc123")
        expect(installation).to have_received(:run_pipeline_with_job!).with(gitlab_integration.code_repository_name, "main", {key: "value"}, "ci_cd_channel", "abc123", GitlabIntegration::WORKFLOW_RUN_TRANSFORMATIONS)
      end
    end

    context "when pipeline trigger fails" do
      it "raises an error" do
        allow(installation).to receive(:run_pipeline_with_job!).and_raise(Installations::Error.new("Pipeline failed", reason: :workflow_run_not_found))
        expect { gitlab_integration.trigger_workflow_run!("ci_cd_channel", "main", {key: "value"}) }.to raise_error(Installations::Error)
      end
    end
  end

  describe "#cancel_workflow_run!" do
    it "calls the GitLab API to cancel a pipeline" do
      allow(installation).to receive(:cancel_job!)
      gitlab_integration.cancel_workflow_run!("123")
      expect(installation).to have_received(:cancel_job!).with(gitlab_integration.code_repository_name, "123")
    end
  end

  describe "#retry_workflow_run!" do
    it "calls the GitLab API to retry a pipeline" do
      allow(installation).to receive(:retry_job!)
      gitlab_integration.retry_workflow_run!("123")
      expect(installation).to have_received(:retry_job!).with(gitlab_integration.code_repository_name, "123", GitlabIntegration::JOB_RUN_TRANSFORMATIONS)
    end
  end

  describe "#get_workflow_run" do
    it "calls the GitLab API to get a pipeline" do
      allow(installation).to receive(:get_job)
      gitlab_integration.get_workflow_run("123")
      expect(installation).to have_received(:get_job).with(gitlab_integration.code_repository_name, "123")
    end
  end

  describe "#create_tag!" do
    it "calls the GitLab API to create a tag" do
      allow(installation).to receive(:create_tag!).and_return({"name" => "v1.0.0"})
      result = gitlab_integration.create_tag!("v1.0.0", "abcdef")
      expect(installation).to have_received(:create_tag!).with(gitlab_integration.code_repository_name, "v1.0.0", "abcdef")
      expect(result).to eq({"name" => "v1.0.0"})
    end

    context "when tag already exists" do
      it "raises an error" do
        allow(installation).to receive(:create_tag!).and_raise(Installations::Gitlab::Error.new({"message" => "Tag v1.0.0 already exists"}))
        expect { gitlab_integration.create_tag!("v1.0.0", "abcdef") }.to raise_error(Installations::Gitlab::Error)
      end
    end

    context "when commit SHA is invalid" do
      it "raises an error" do
        allow(installation).to receive(:create_tag!).and_raise(Installations::Gitlab::Error.new({"message" => "Invalid commit SHA"}))
        expect { gitlab_integration.create_tag!("v1.0.0", "invalid_sha") }.to raise_error(Installations::Gitlab::Error)
      end
    end
  end

  describe "#create_patch_pr!" do
    it "calls the GitLab API to cherry pick a commit" do
      allow(installation).to receive(:cherry_pick_pr).and_return({})
      gitlab_integration.create_patch_pr!("main", "patch-branch", "abcdef", "PR Title")
      expect(installation).to have_received(:cherry_pick_pr).with(gitlab_integration.code_repository_name, "main", "abcdef", "patch-branch", "PR Title", "", GitlabIntegration::PR_TRANSFORMATIONS)
    end

    context "with custom description" do
      it "passes description to cherry_pick_pr" do
        allow(installation).to receive(:cherry_pick_pr).and_return({})
        gitlab_integration.create_patch_pr!("main", "patch-branch", "abcdef", "PR Title", "Custom description")
        expect(installation).to have_received(:cherry_pick_pr).with(gitlab_integration.code_repository_name, "main", "abcdef", "patch-branch", "PR Title", "Custom description", GitlabIntegration::PR_TRANSFORMATIONS)
      end
    end

    context "when cherry-pick fails" do
      it "raises an error" do
        allow(installation).to receive(:cherry_pick_pr).and_raise(Installations::Gitlab::Error.new({"message" => "Cherry-pick failed"}))
        expect { gitlab_integration.create_patch_pr!("main", "patch-branch", "abcdef", "PR Title") }.to raise_error(Installations::Gitlab::Error)
      end
    end
  end

  describe "#enable_auto_merge!" do
    it "calls the GitLab API to enable auto merge" do
      allow(installation).to receive(:enable_auto_merge).and_return(true)
      result = gitlab_integration.enable_auto_merge!(123)
      expect(installation).to have_received(:enable_auto_merge).with(gitlab_integration.code_repository_name, 123)
      expect(result).to be true
    end

    context "when PR is already merged" do
      it "returns early" do
        allow(installation).to receive(:enable_auto_merge).and_return(nil)
        result = gitlab_integration.enable_auto_merge!(123)
        expect(result).to be_nil
      end
    end

    context "when enable auto merge fails" do
      it "raises an error" do
        allow(installation).to receive(:enable_auto_merge).and_raise(Installations::Gitlab::Error.new({"message" => "Cannot enable auto merge"}))
        expect(gitlab_integration.enable_auto_merge!(123)).to be(false)
      end
    end
  end

  describe "#bot_name" do
    it "returns the bot name" do
      expect(gitlab_integration.bot_name).to eq("gitlab-bot")
    end
  end

  describe "#user_info" do
    it "calls the GitLab API to get user info" do
      allow(installation).to receive(:user_info).and_return({id: 123, username: "testuser", name: "Test User"})
      result = gitlab_integration.user_info
      expect(installation).to have_received(:user_info).with(GitlabIntegration::USER_INFO_TRANSFORMATIONS)
      expect(result).to eq({id: 123, username: "testuser", name: "Test User"})
    end

    it "ignores the branch parameter" do
      allow(installation).to receive(:user_info).and_return({id: 123, username: "testuser"})
      gitlab_integration.user_info
      expect(installation).to have_received(:user_info).with(GitlabIntegration::USER_INFO_TRANSFORMATIONS)
    end
  end

  describe "token keepalive callback" do
    let(:new_gitlab_integration) { build(:gitlab_integration, oauth_access_token: "test_token", oauth_refresh_token: "test_refresh_token") }

    before do
      # Mock the API calls so validation passes without an integration
      allow_any_instance_of(described_class).to receive(:complete_access)
      allow_any_instance_of(described_class).to receive(:correct_key)
    end

    it "schedules the keepalive job after creation" do
      allow(KeepAliveIntegrations::GitlabJob).to receive(:perform_in)

      new_gitlab_integration.save!

      expect(KeepAliveIntegrations::GitlabJob).to have_received(:perform_in).with(6.hours, new_gitlab_integration.id)
    end
  end

  describe "#complete_access" do
    let(:mock_api) { class_double(Installations::Gitlab::Api) }
    let(:fresh_tokens) { OpenStruct.new(access_token: "fresh_access", refresh_token: "fresh_refresh") }
    let(:reauth_integration) do
      create(:integration, integrable: app, category: "version_control",
        providable: build(:gitlab_integration, :without_callbacks_and_validations)).tap(&:mark_needs_reauth!)
    end

    before { stub_const("GitlabIntegration::API", mock_api) }

    def reauthorize(integration_id, code:)
      Integration.find(integration_id).tap do |reloaded|
        allow(reloaded.providable).to receive(:redirect_uri).and_return("redirect_uri")
        reloaded.providable.assign_attributes(code:)
        reloaded.status = Integration::DEFAULT_CONNECT_STATUS
      end
    end

    it "exchanges the code exactly once when creating an integration" do
      allow(mock_api).to receive(:oauth_access_token).and_return(fresh_tokens)
      allow_any_instance_of(described_class).to receive(:redirect_uri).and_return("redirect_uri")
      allow_any_instance_of(described_class).to receive(:correct_key)
      new_integration = create(:app, :android).integrations.new(category: "version_control", status: Integration::DEFAULT_CONNECT_STATUS)
      new_integration.providable = described_class.new(integration: new_integration, code: "new_code")

      expect(new_integration.save).to be(true)
      expect(mock_api).to have_received(:oauth_access_token).once
      expect(new_integration.providable.reload.oauth_access_token).to eq("fresh_access")
    end

    it "exchanges a new code for tokens when re-authorizing an existing integration" do
      allow(mock_api).to receive(:oauth_access_token).with("new_code", "redirect_uri").and_return(fresh_tokens)
      reloaded = reauthorize(reauth_integration.id, code: "new_code")

      expect(reloaded.save).to be(true)

      providable = reloaded.providable.reload
      expect(providable.oauth_access_token).to eq("fresh_access")
      expect(providable.oauth_refresh_token).to eq("fresh_refresh")
      expect(reloaded.reload).to be_connected
    end

    it "keeps the integration needing re-authorization when the code exchange returns no tokens" do
      allow(mock_api).to receive(:oauth_access_token).and_return(OpenStruct.new)
      old_access_token = reauth_integration.providable.oauth_access_token
      reloaded = reauthorize(reauth_integration.id, code: "expired_code")

      expect(reloaded.save).to be(false)
      expect(reloaded.providable.reload.oauth_access_token).to eq(old_access_token)
      expect(Integration.find(reauth_integration.id)).to be_needs_reauth
    end
  end

  describe "#with_api_retries (private)" do
    context "when token expires" do
      let(:error) { Installations::Error.new("Token expired", reason: :token_expired) }

      it "retries after refreshing token" do
        call_count = 0
        allow(gitlab_integration).to receive(:reset_tokens!)

        result = gitlab_integration.send(:with_api_retries) do
          call_count += 1
          raise error if call_count == 1
          "success"
        end

        expect(gitlab_integration).to have_received(:reset_tokens!).once
        expect(result).to eq("success")
      end
    end

    context "when max retries exceeded" do
      it "raises the error" do
        expect do
          gitlab_integration.send(:with_api_retries) { raise Installations::Gitlab::Error.new({}) }
        end.to raise_error(Installations::Gitlab::Error)
      end
    end
  end

  describe "#reset_tokens! (private)" do
    let(:mock_api) { class_double(Installations::Gitlab::Api) }
    let(:valid_tokens) { OpenStruct.new(access_token: "new_access", refresh_token: "new_refresh") }

    before do
      stub_const("GitlabIntegration::API", mock_api)
      allow(gitlab_integration).to receive_messages(redirect_uri: "redirect_uri")
    end

    context "when successful" do
      def gitlab_provider_with(refresh_token, integrable:)
        create(:integration, integrable:, category: "version_control",
          providable: build(:gitlab_integration, :without_callbacks_and_validations, oauth_refresh_token: refresh_token)).providable
      end

      before do
        gitlab_integration.update!(oauth_refresh_token: "shared_refresh")
        allow(mock_api).to receive(:oauth_refresh_token).with("shared_refresh", "redirect_uri").and_return(valid_tokens)
      end

      it "stores the refreshed tokens on integrations sharing the grant across the organization's apps" do
        sibling = gitlab_provider_with("shared_refresh", integrable: app)
        reused_copy = gitlab_provider_with("shared_refresh", integrable: create(:app, :android, organization: app.organization))

        gitlab_integration.send(:reset_tokens!)

        [gitlab_integration, sibling, reused_copy].each do |provider|
          provider.reload
          expect(provider.oauth_access_token).to eq("new_access")
          expect(provider.oauth_refresh_token).to eq("new_refresh")
        end
      end

      it "leaves integrations with their own grant or in other organizations untouched" do
        independent = gitlab_provider_with("independent_refresh", integrable: app)
        other_org_copy = gitlab_provider_with("shared_refresh", integrable: create(:app, :android))

        gitlab_integration.send(:reset_tokens!)

        expect(independent.reload.oauth_refresh_token).to eq("independent_refresh")
        expect(other_org_copy.reload.oauth_refresh_token).to eq("shared_refresh")
      end
    end

    context "when token refresh fails" do
      before do
        allow(integration).to receive(:mark_needs_reauth!)
      end

      {
        "response is nil" => nil,
        "access token is missing" => OpenStruct.new(access_token: "", refresh_token: "refresh"),
        "refresh token is missing" => OpenStruct.new(access_token: "access", refresh_token: "")
      }.each do |case_name, invalid_tokens|
        it "marks integration as needs_reauth when #{case_name}" do
          allow(mock_api).to receive(:oauth_refresh_token).and_return(invalid_tokens)

          expect {
            gitlab_integration.send(:reset_tokens!)
          }.to raise_error(Installations::Error::TokenRefreshFailure)

          expect(integration).to have_received(:mark_needs_reauth!)
        end
      end
    end
  end
end
