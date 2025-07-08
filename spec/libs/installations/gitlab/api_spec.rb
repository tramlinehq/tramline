require "rails_helper"

RSpec.describe Installations::Gitlab::Api do
  let(:api) { described_class.new("access_token") }

  describe "#get_file_content" do
    let(:project_id) { "123" }
    let(:branch_name) { "main" }
    let(:file_path) { "path/to/file.txt" }
    let(:file_content) { "This is the file content." }
    let(:encoded_content) { Base64.encode64(file_content) }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/repository/files/path%252Fto%252Ffile.txt?ref=#{branch_name}" }

    it "returns the file content" do
      stub_request(:get, url)
        .with(headers: {"Authorization" => "Bearer access_token"})
        .to_return(status: 200, body: {"content" => encoded_content}.to_json, headers: {"Content-Type" => "application/json"})

      expect(api.get_file_content(project_id, branch_name, file_path)).to eq(file_content)
    end

    context "when the file is not found" do
      it "raises an error" do
        stub_request(:get, url)
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 404, body: {"message" => "404 File Not Found"}.to_json, headers: {"Content-Type" => "application/json"})

        expect { api.get_file_content(project_id, branch_name, file_path) }.to raise_error(Installations::Gitlab::Error)
      end
    end
  end

  describe "#update_file!" do
    let(:project_id) { "123" }
    let(:branch_name) { "main" }
    let(:file_path) { "path/to/file.txt" }
    let(:file_content) { "This is the new file content." }
    let(:commit_message) { "Update file.txt" }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/repository/files/#{ERB::Util.url_encode(file_path)}" }

    it "updates the file content" do
      stub_request(:put, url)
        .with(
          body: {
            branch: branch_name,
            content: file_content,
            commit_message: commit_message
          }.to_json,
          headers: {
            "Authorization" => "Bearer access_token",
            "Content-Type" => "application/json; charset=utf-8"
          }
        )
        .to_return(status: 200, body: "", headers: {})

      api.update_file!(project_id, branch_name, file_path, file_content, commit_message)
    end
  end

  describe "#create_release!" do
    let(:project_id) { "123" }
    let(:tag_name) { "v1.0.0" }
    let(:branch) { "main" }
    let(:description) { "This is a new release." }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/releases" }

    it "creates a new release" do
      stub_request(:post, url)
        .with(
          body: {
            tag_name: tag_name,
            ref: branch,
            description: description
          }.to_json,
          headers: {
            "Authorization" => "Bearer access_token",
            "Content-Type" => "application/json; charset=utf-8"
          }
        )
        .to_return(status: 201, body: "", headers: {})

      api.create_release!(project_id, tag_name, branch, description)
    end
  end

  describe "#user_info" do
    before do
      stub_request(:get, "https://gitlab.com/api/v4/user")
        .to_return_json(body: {
          id: 317941,
          username: "example-user",
          name: "Example User",
          avatar_url: "https://gitlab.com/uploads/-/system/user/avatar/317941/avatar.png"
        })
    end

    it "returns the transformed user info" do
      result = described_class.new("access_token").user_info(GitlabIntegration::USER_INFO_TRANSFORMATIONS)
      expect(result).to eq({
        "avatar_url" => "https://gitlab.com/uploads/-/system/user/avatar/317941/avatar.png",
        "id" => "317941",
        "name" => "Example User",
        "username" => "example-user"
      })
    end
  end

  describe "#list_projects" do
    let(:url) { "https://gitlab.com/api/v4/projects?membership=true&per_page=50" }
    let(:projects) { [{ id: "1", name: "Project 1" }, { id: "2", name: "Project 2" }] }

    it "returns a list of projects" do
      stub_request(:get, url)
        .with(headers: {"Authorization" => "Bearer access_token"})
        .to_return(status: 200, body: projects.to_json, headers: {"Content-Type" => "application/json"})

      expect(api.list_projects({ id: :id, name: :name })).to eq(projects.map(&:with_indifferent_access))
    end

    context "when there are multiple pages of projects" do
      let(:url2) { "https://gitlab.com/api/v4/projects?membership=true&per_page=50&page=2" }
      let(:projects2) { [{ id: "3", name: "Project 3" }, { id: "4", name: "Project 4" }] }

      it "returns all projects" do
        stub_request(:get, url)
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: projects.to_json, headers: {"Content-Type" => "application/json", "x-next-page" => "2"})

        stub_request(:get, url2)
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: projects2.to_json, headers: {"Content-Type" => "application/json", "x-next-page" => ""})

        expect(api.list_projects({ id: :id, name: :name })).to eq((projects + projects2).map(&:with_indifferent_access))
      end
    end
  end

  describe "#enable_auto_merge" do
    let(:project_id) { "123" }
    let(:pr_number) { "456" }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/merge_requests/#{pr_number}/merge" }

    it "enables auto-merge for a pull request" do
      stub_request(:put, url)
        .with(
          body: { "should_remove_source_branch" => true, "merge_when_pipeline_succeeds" => true }.to_json,
          headers: {
            "Authorization" => "Bearer access_token",
            "Content-Type" => "application/json; charset=utf-8"
          }
        )
        .to_return(status: 200, body: "", headers: {})

      api.enable_auto_merge(project_id, pr_number)
    end
  end

  describe "#run_pipeline!" do
    let(:project_id) { "123" }
    let(:branch_name) { "main" }
    let(:inputs) { { "foo" => "bar" } }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/pipeline?ref=#{branch_name}" }

    it "runs a pipeline" do
      stub_request(:post, url)
        .with(
          body: { variables: [{ key: "foo", value: "bar" }] }.to_json,
          headers: {
            "Authorization" => "Bearer access_token",
            "Content-Type" => "application/json; charset=utf-8"
          }
        )
        .to_return(status: 201, body: {id: 1}.to_json, headers: {"Content-Type" => "application/json"})

      api.run_pipeline!(project_id, branch_name, inputs, { id: :id })
    end
  end

  describe "#cancel_pipeline!" do
    let(:project_id) { "123" }
    let(:pipeline_id) { "456" }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/pipelines/#{pipeline_id}/cancel" }

    it "cancels a pipeline" do
      stub_request(:post, url)
        .with(headers: {"Authorization" => "Bearer access_token"})
        .to_return(status: 200, body: "", headers: {})

      api.cancel_pipeline!(project_id, pipeline_id)
    end
  end

  describe "#retry_pipeline!" do
    let(:project_id) { "123" }
    let(:pipeline_id) { "456" }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/pipelines/#{pipeline_id}/retry" }

    it "retries a pipeline" do
      stub_request(:post, url)
        .with(headers: {"Authorization" => "Bearer access_token"})
        .to_return(status: 201, body: "", headers: {})

      api.retry_pipeline!(project_id, pipeline_id)
    end
  end

  describe "#get_pipeline" do
    let(:project_id) { "123" }
    let(:pipeline_id) { "456" }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/pipelines/#{pipeline_id}" }
    let(:pipeline) { { id: pipeline_id, status: "success" } }

    it "returns a pipeline" do
      stub_request(:get, url)
        .with(headers: {"Authorization" => "Bearer access_token"})
        .to_return(status: 200, body: pipeline.to_json, headers: {"Content-Type" => "application/json"})

      expect(api.get_pipeline(project_id, pipeline_id, { id: :id, status: :status })).to eq(pipeline.with_indifferent_access)
    end
  end

  describe "#create_annotated_tag!" do
    let(:project_id) { "123" }
    let(:tag_name) { "v1.0.0" }
    let(:branch_name) { "main" }
    let(:message) { "This is an annotated tag." }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/repository/tags" }

    it "creates an annotated tag" do
      stub_request(:post, url)
        .with(
          body: { tag_name: tag_name, ref: branch_name, message: message }.to_json,
          headers: {
            "Authorization" => "Bearer access_token",
            "Content-Type" => "application/json; charset=utf-8"
          }
        )
        .to_return(status: 201, body: "", headers: {})

      api.create_annotated_tag!(project_id, tag_name, branch_name, message)
    end
  end

  describe "#assign_pr" do
    let(:project_id) { "123" }
    let(:pr_number) { "456" }
    let(:assignee_id) { "789" }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/merge_requests/#{pr_number}" }

    it "assigns a pull request to a user" do
      stub_request(:put, url)
        .with(
          body: { assignee_ids: [assignee_id] }.to_json,
          headers: {
            "Authorization" => "Bearer access_token",
            "Content-Type" => "application/json; charset=utf-8"
          }
        )
        .to_return(status: 200, body: "", headers: {})

      api.assign_pr(project_id, pr_number, assignee_id)
    end
  end

  describe "#cherry_pick_pr" do
    let(:project_id) { "123" }
    let(:pr_number) { "456" }
    let(:branch_name) { "main" }
    let(:patch_branch_name) { "cherry-pick-branch" }
    let(:commit_sha) { "abc1234" }
    let(:cherry_pick_url) { "https://gitlab.com/api/v4/projects/#{project_id}/repository/commits/#{commit_sha}/cherry_pick" }
    let(:create_branch_url) { "https://gitlab.com/api/v4/projects/#{project_id}/repository/branches" }
    let(:create_pr_url) { "https://gitlab.com/api/v4/projects/#{project_id}/merge_requests" }

    it "cherry-picks a pull request" do
      stub_request(:post, create_branch_url)
        .with(
          body: { branch: patch_branch_name, ref: branch_name }.to_json,
          headers: {
            "Authorization" => "Bearer access_token",
            "Content-Type" => "application/json; charset=utf-8"
          }
        )
        .to_return(status: 201, body: "", headers: {})

      stub_request(:post, cherry_pick_url)
        .with(
          body: { branch: patch_branch_name }.to_json,
          headers: {
            "Authorization" => "Bearer access_token",
            "Content-Type" => "application/json; charset=utf-8"
          }
        )
        .to_return(status: 201, body: {id: 1}.to_json, headers: {"Content-Type" => "application/json"})

      stub_request(:post, create_pr_url)
        .with(
          body: { source_branch: patch_branch_name, target_branch: branch_name, title: "Cherry-pick #{commit_sha}", description: "" }.to_json,
          headers: {
            "Authorization" => "Bearer access_token",
            "Content-Type" => "application/json; charset=utf-8"
          }
        )
        .to_return(status: 201, body: {id: 1}.to_json, headers: {"Content-Type" => "application/json"})

      stub_request(:get, "https://gitlab.com/api/v4/projects/#{project_id}/repository/compare?from=#{branch_name}&straight=false&to=#{patch_branch_name}")
        .with(headers: {"Authorization" => "Bearer access_token"})
        .to_return(status: 200, body: {diffs: [{}]}.to_json, headers: {"Content-Type" => "application/json"})

      api.cherry_pick_pr(project_id, pr_number, branch_name, patch_branch_name, commit_sha, { id: :id })
    end
  end
end
