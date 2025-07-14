require "rails_helper"

describe Installations::Gitlab::Api do
  let(:api) { described_class.new("access_token") }

  describe "#list_pipeline_jobs" do
    let(:project_id) { "123" }
    let(:pipeline_id) { "456" }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/pipelines/#{pipeline_id}/jobs" }
    let(:jobs) { [{"id" => "1", "name" => "build", "status" => "success", "stage" => "test"}] }

    it "returns pipeline jobs" do
      stub_request(:get, url)
        .with(headers: {"Authorization" => "Bearer access_token"})
        .to_return(status: 200, body: jobs.to_json, headers: {"Content-Type" => "application/json"})

      result = api.list_pipeline_jobs(project_id, pipeline_id)
      expect(result).to eq(jobs.map(&:with_indifferent_access))
    end

    context "when pipeline has no jobs" do
      it "returns empty array" do
        stub_request(:get, url)
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: [].to_json, headers: {"Content-Type" => "application/json"})

        result = api.list_pipeline_jobs(project_id, pipeline_id)
        expect(result).to eq([])
      end
    end
  end

  describe "#trigger_job!" do
    let(:project_id) { "123" }
    let(:job_id) { "456" }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/jobs/#{job_id}/play" }
    let(:transforms) { {id: :id, status: :status} }

    it "triggers a job" do
      stub_request(:post, url)
        .with(headers: {"Authorization" => "Bearer access_token"})
        .to_return(status: 200, body: {id: job_id, status: "running"}.to_json, headers: {"Content-Type" => "application/json"})

      result = api.trigger_job!(project_id, job_id, transforms)
      expect(result[:id]).to eq(job_id)
      expect(result[:status]).to eq("running")
    end

    context "when job is not playable" do
      it "raises an error" do
        stub_request(:post, url)
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 400, body: {"message" => "Unplayable Job"}.to_json, headers: {"Content-Type" => "application/json"})

        expect { api.trigger_job!(project_id, job_id, transforms) }.to raise_error(Installations::Gitlab::Error)
      end
    end
  end

  describe "#run_pipeline_with_job!" do
    let(:project_id) { "123" }
    let(:branch_name) { "main" }
    let(:job_name) { "test_job" }
    let(:commit_sha) { "abc123" }
    let(:inputs) { {parameters: {"foo" => "bar"}} }
    let(:transforms) { {ci_ref: :id, ci_link: :web_url} }

    context "when existing pipeline is found" do
      it "triggers job in existing pipeline" do
        existing_pipeline = {ci_ref: "789", ci_link: "http://example.com"}
        allow(api).to receive_messages(find_existing_pipeline: existing_pipeline, trigger_specific_job_in_pipeline: {id: "job1"})

        result = api.run_pipeline_with_job!(project_id, branch_name, inputs, job_name, commit_sha, transforms)
        expect(result).to eq({id: "job1"})
      end
    end

    context "when no existing pipeline is found" do
      it "creates new pipeline and triggers job" do
        new_pipeline = {ci_ref: "999", ci_link: "http://example.com"}
        allow(api).to(
          receive_messages(
            find_existing_pipeline: nil,
            run_pipeline!: new_pipeline,
            trigger_specific_job_in_pipeline: {id: "job2"}
          )
        )

        result = api.run_pipeline_with_job!(project_id, branch_name, inputs, job_name, commit_sha, transforms)
        expect(result).to eq({id: "job2"})
      end
    end

    context "when job is not found" do
      it "raises JOB_NOT_FOUND error" do
        allow(api).to(receive_messages(
          find_existing_pipeline: nil,
          run_pipeline!: {ci_ref: "999"},
          trigger_specific_job_in_pipeline: nil
        ))

        expect { api.run_pipeline_with_job!(project_id, branch_name, inputs, job_name, commit_sha, transforms) }
          .to raise_error(Installations::Error, "GitLab Job not found")
      end
    end
  end

  describe "#list_jobs_from_gitlab_ci" do
    let(:project_id) { "123" }
    let(:branch_name) { "main" }

    context "with valid gitlab-ci.yml" do
      let(:yaml_content) do
        <<~YAML
          stages:
            - test
            - build

          variables:
            SOME_VAR: value

          test_job:
            stage: test
            script:
              - echo "testing"

          build_job:
            stage: build
            script:
              - echo "building"

          .hidden_job:
            script:
              - echo "hidden"
        YAML
      end

      it "returns list of jobs excluding hidden and global keys" do
        allow(api).to receive(:get_file_content).and_return(yaml_content)

        result = api.list_jobs_from_gitlab_ci(project_id, branch_name)
        expect(result).to contain_exactly(
          {id: "test_job", name: "test_job"},
          {id: "build_job", name: "build_job"}
        )
      end
    end

    context "when gitlab-ci.yml doesn't exist" do
      it "returns empty array" do
        allow(api).to receive(:get_file_content).and_return(nil)

        result = api.list_jobs_from_gitlab_ci(project_id, branch_name)
        expect(result).to eq([])
      end
    end

    context "when gitlab-ci.yml has syntax error" do
      it "returns empty array and logs warning" do
        invalid_yaml = "invalid: yaml: content: ["
        allow(api).to receive(:get_file_content).and_return(invalid_yaml)
        allow(Rails.logger).to receive(:warn)

        result = api.list_jobs_from_gitlab_ci(project_id, branch_name)
        expect(result).to eq([])
        expect(Rails.logger).to have_received(:warn).with(/Failed to parse .gitlab-ci.yml/)
      end
    end

    context "when file fetch fails" do
      it "returns empty array and logs warning" do
        allow(api).to receive(:get_file_content).and_raise(Installations::Error.new("File not found", reason: :file_not_found))
        allow(Rails.logger).to receive(:warn)

        result = api.list_jobs_from_gitlab_ci(project_id, branch_name)
        expect(result).to eq([])
        expect(Rails.logger).to have_received(:warn).with(/Failed to fetch .gitlab-ci.yml/)
      end
    end
  end

  describe "#get_file_content" do
    let(:project_id) { "123" }
    let(:branch_name) { "main" }
    let(:file_path) { "path/to/file.txt" }
    let(:file_content) { "This is the file content." }
    let(:encoded_content) { Base64.encode64(file_content) }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/repository/files/path%2Fto%2Ffile.txt?ref=#{branch_name}" }

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

    context "when response has no content" do
      it "returns nil" do
        stub_request(:get, url)
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: {}.to_json, headers: {"Content-Type" => "application/json"})

        expect { api.get_file_content(project_id, branch_name, file_path) }.to raise_error(Installations::Error)
      end
    end

    context "when server returns 500 error" do
      it "raises a service unavailable error" do
        stub_request(:get, url)
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 500, body: "Internal Server Error", headers: {})

        expect { api.get_file_content(project_id, branch_name, file_path) }.to raise_error(Installations::Gitlab::Error)
      end
    end

    context "when content is empty string" do
      it "returns empty string" do
        empty_content = Base64.encode64("")
        stub_request(:get, url)
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: {"content" => empty_content}.to_json, headers: {"Content-Type" => "application/json"})

        expect(api.get_file_content(project_id, branch_name, file_path)).to eq("")
      end
    end
  end

  describe "#update_file!" do
    let(:project_id) { "123" }
    let(:branch_name) { "main" }
    let(:file_path) { "path/to/file.txt" }
    let(:file_content) { "This is the new file content." }
    let(:commit_message) { "Update file.txt" }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/repository/files/path%252Fto%252Ffile.txt" }

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

      expect(api.update_file!(project_id, branch_name, file_path, file_content, commit_message)).to be_truthy
    end

    context "with author information" do
      it "includes author name and email" do
        stub_request(:put, url)
          .with(
            body: {
              branch: branch_name,
              content: file_content,
              commit_message: commit_message,
              author_name: "Test Author",
              author_email: "test@example.com"
            }.to_json,
            headers: {
              "Authorization" => "Bearer access_token",
              "Content-Type" => "application/json; charset=utf-8"
            }
          )
          .to_return(status: 200, body: "", headers: {})

        expect(api.update_file!(project_id, branch_name, file_path, file_content, commit_message, author_name: "Test Author", author_email: "test@example.com")).to be_truthy
      end
    end

    context "when file doesn't exist" do
      it "raises not found error" do
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
          .to_return(status: 404, body: {"message" => "File not found"}.to_json, headers: {"Content-Type" => "application/json"})

        expect { api.update_file!(project_id, branch_name, file_path, file_content, commit_message) }.to raise_error(Installations::Gitlab::Error)
      end
    end
  end

  describe "#create_release!" do
    let(:project_id) { "123" }
    let(:tag_name) { "v1.0.0" }
    let(:branch) { "main" }
    let(:description) { "This is a new release." }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/releases" }

    context "when tag doesn't exist" do
      it "creates tag first then creates release" do
        # Stub the tag_exists? check
        stub_request(:get, "https://gitlab.com/api/v4/projects/#{project_id}/repository/tags/#{tag_name}")
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 404, body: {"message" => "404 Tag Not Found"}.to_json, headers: {"Content-Type" => "application/json"})

        # Stub the create_tag! call
        stub_request(:post, "https://gitlab.com/api/v4/projects/#{project_id}/repository/tags")
          .with(
            body: {"tag_name" => tag_name, "ref" => branch},
            headers: {
              "Authorization" => "Bearer access_token",
              "Content-Type" => "application/x-www-form-urlencoded"
            }
          )
          .to_return(status: 201, body: {"name" => tag_name}.to_json, headers: {"Content-Type" => "application/json"})

        # Stub the create_release! call
        stub_request(:post, url)
          .with(
            body: {
              tag_name: tag_name,
              description: description
            }.to_json,
            headers: {
              "Authorization" => "Bearer access_token",
              "Content-Type" => "application/json; charset=utf-8"
            }
          )
          .to_return(status: 201, body: {"tag_name" => tag_name}.to_json, headers: {"Content-Type" => "application/json"})

        expect(api.create_release!(project_id, tag_name, branch, description)).to be_truthy
      end
    end

    context "when tag already exists" do
      it "skips tag creation and creates release" do
        # Stub the tag_exists? check
        stub_request(:get, "https://gitlab.com/api/v4/projects/#{project_id}/repository/tags/#{tag_name}")
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: {"name" => tag_name}.to_json, headers: {"Content-Type" => "application/json"})

        # Stub the create_release! call (no tag creation expected)
        stub_request(:post, url)
          .with(
            body: {
              tag_name: tag_name,
              description: description
            }.to_json,
            headers: {
              "Authorization" => "Bearer access_token",
              "Content-Type" => "application/json; charset=utf-8"
            }
          )
          .to_return(status: 201, body: {"tag_name" => tag_name}.to_json, headers: {"Content-Type" => "application/json"})

        expect(api.create_release!(project_id, tag_name, branch, description)).to be_truthy
      end
    end

    context "when release already exists" do
      it "raises an error" do
        # Stub the tag_exists? check
        stub_request(:get, "https://gitlab.com/api/v4/projects/#{project_id}/repository/tags/#{tag_name}")
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: {"name" => tag_name}.to_json, headers: {"Content-Type" => "application/json"})

        # Stub the create_release! call to return error
        stub_request(:post, url)
          .with(
            body: {
              tag_name: tag_name,
              description: description
            }.to_json,
            headers: {
              "Authorization" => "Bearer access_token",
              "Content-Type" => "application/json; charset=utf-8"
            }
          )
          .to_return(status: 409, body: {"message" => "Release already exists"}.to_json, headers: {"Content-Type" => "application/json"})

        expect { api.create_release!(project_id, tag_name, branch, description) }.to raise_error(Installations::Gitlab::Error)
      end
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
    let(:projects) { [{"id" => "1", "name" => "Project 1"}, {"id" => "2", "name" => "Project 2"}] }

    it "returns a list of projects" do
      stub_request(:get, url)
        .with(headers: {"Authorization" => "Bearer access_token"})
        .to_return(status: 200, body: projects.to_json, headers: {"Content-Type" => "application/json"})

      expect(api.list_projects({"id" => :id, "name" => :name})).to eq(projects.map(&:with_indifferent_access))
    end

    context "when there are multiple pages of projects" do
      let(:url2) { "https://gitlab.com/api/v4/projects?membership=true&per_page=50&page=2" }
      let(:projects2) { [{"id" => "3", "name" => "Project 3"}, {"id" => "4", "name" => "Project 4"}] }

      it "returns all projects" do
        stub_request(:get, url)
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: projects.to_json, headers: {"Content-Type" => "application/json", "x-next-page" => "2"})

        stub_request(:get, url2)
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: projects2.to_json, headers: {"Content-Type" => "application/json", "x-next-page" => ""})

        expect(api.list_projects({"id" => :id, "name" => :name})).to eq((projects + projects2).map(&:with_indifferent_access))
      end
    end

    context "when no projects are found" do
      it "returns an empty array" do
        stub_request(:get, url)
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: [].to_json, headers: {"Content-Type" => "application/json"})

        expect(api.list_projects({"id" => :id, "name" => :name})).to eq([])
      end
    end

    context "when max_results is exceeded" do
      let(:many_projects) { (1..250).map { |i| {"id" => i.to_s, "name" => "Project #{i}"} } }

      it "limits results to max_results" do
        stub_request(:get, url)
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: many_projects[0...50].to_json, headers: {"Content-Type" => "application/json", "x-next-page" => "2"})

        stub_request(:get, "https://gitlab.com/api/v4/projects?membership=true&per_page=50&page=2")
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: many_projects[50...100].to_json, headers: {"Content-Type" => "application/json", "x-next-page" => "3"})

        stub_request(:get, "https://gitlab.com/api/v4/projects?membership=true&per_page=50&page=3")
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: many_projects[100...150].to_json, headers: {"Content-Type" => "application/json", "x-next-page" => "4"})

        stub_request(:get, "https://gitlab.com/api/v4/projects?membership=true&per_page=50&page=4")
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: many_projects[150...200].to_json, headers: {"Content-Type" => "application/json", "x-next-page" => ""})

        result = api.list_projects({"id" => :id, "name" => :name})
        expect(result.length).to eq(200)  # max_results default is 200
      end
    end
  end

  describe "#enable_auto_merge" do
    let(:project_id) { "123" }
    let(:pr_number) { "456" }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/merge_requests/#{pr_number}/merge" }

    context "when PR is not merged" do
      it "enables auto-merge for a pull request" do
        # Stub the get_pr call to check if PR is merged
        stub_request(:get, "https://gitlab.com/api/v4/projects/#{project_id}/merge_requests/#{pr_number}")
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: {"state" => "opened"}.to_json, headers: {"Content-Type" => "application/json"})

        stub_request(:put, url)
          .with(
            body: {"should_remove_source_branch" => true, "auto_merge" => true}.to_json,
            headers: {
              "Authorization" => "Bearer access_token",
              "Content-Type" => "application/json; charset=utf-8"
            }
          )
          .to_return(status: 200, body: "", headers: {})

        expect(api.enable_auto_merge(project_id, pr_number)).to be_truthy
      end
    end

    context "when PR is already merged" do
      it "returns early without making merge request" do
        # Stub the get_pr call to check if PR is merged
        stub_request(:get, "https://gitlab.com/api/v4/projects/#{project_id}/merge_requests/#{pr_number}")
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: {"state" => "merged"}.to_json, headers: {"Content-Type" => "application/json"})

        # No merge request should be made
        expect(api.enable_auto_merge(project_id, pr_number)).to be_nil
      end
    end

    context "when PR is closed" do
      it "still attempts to enable auto-merge" do
        # Stub the get_pr call to check if PR is merged
        stub_request(:get, "https://gitlab.com/api/v4/projects/#{project_id}/merge_requests/#{pr_number}")
          .with(headers: {"Authorization" => "Bearer access_token"})
          .to_return(status: 200, body: {"state" => "closed"}.to_json, headers: {"Content-Type" => "application/json"})

        stub_request(:put, url)
          .with(
            body: {"should_remove_source_branch" => true, "auto_merge" => true}.to_json,
            headers: {
              "Authorization" => "Bearer access_token",
              "Content-Type" => "application/json; charset=utf-8"
            }
          )
          .to_return(status: 409, body: {"message" => "Branch cannot be merged"}.to_json, headers: {"Content-Type" => "application/json"})

        expect { api.enable_auto_merge(project_id, pr_number) }.to raise_error(Installations::Gitlab::Error)
      end
    end
  end

  describe "#run_pipeline!" do
    let(:project_id) { "123" }
    let(:branch_name) { "main" }
    let(:inputs) { {parameters: {"foo" => "bar"}} }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/pipeline?ref=#{branch_name}" }

    it "runs a pipeline with custom parameters" do
      stub_request(:post, url)
        .with(
          body: {variables: [{key: "foo", value: "bar"}]}.to_json,
          headers: {
            "Authorization" => "Bearer access_token",
            "Content-Type" => "application/json; charset=utf-8"
          }
        )
        .to_return(status: 201, body: {id: 1}.to_json, headers: {"Content-Type" => "application/json"})

      expect(api.run_pipeline!(project_id, branch_name, inputs, {id: :id})).to be_truthy
    end

    context "with build inputs" do
      let(:inputs) { {version_code: "123", build_version: "1.0.0", build_notes: "Test build", parameters: {"custom" => "value"}} }

      it "includes all build variables" do
        stub_request(:post, url)
          .with(
            body: {variables: [
              {key: "versionCode", value: "123"},
              {key: "versionName", value: "1.0.0"},
              {key: "buildNotes", value: "Test build"},
              {key: "custom", value: "value"}
            ]}.to_json,
            headers: {
              "Authorization" => "Bearer access_token",
              "Content-Type" => "application/json; charset=utf-8"
            }
          )
          .to_return(status: 201, body: {id: 1}.to_json, headers: {"Content-Type" => "application/json"})

        expect(api.run_pipeline!(project_id, branch_name, inputs, {id: :id})).to be_truthy
      end
    end

    context "when pipeline creation fails" do
      it "raises an error" do
        stub_request(:post, url)
          .with(
            body: {variables: [{key: "foo", value: "bar"}]}.to_json,
            headers: {
              "Authorization" => "Bearer access_token",
              "Content-Type" => "application/json; charset=utf-8"
            }
          )
          .to_return(status: 400, body: {"message" => "Pipeline creation failed"}.to_json, headers: {"Content-Type" => "application/json"})

        expect { api.run_pipeline!(project_id, branch_name, inputs, {id: :id}) }.to raise_error(Installations::Gitlab::Error)
      end
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

      expect(api.cancel_pipeline!(project_id, pipeline_id)).to be_truthy
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

      expect(api.retry_pipeline!(project_id, pipeline_id)).to be_truthy
    end
  end

  describe "#get_pipeline" do
    let(:project_id) { "123" }
    let(:pipeline_id) { "456" }
    let(:url) { "https://gitlab.com/api/v4/projects/#{project_id}/pipelines/#{pipeline_id}" }
    let(:pipeline) { {id: pipeline_id, status: "success"} }

    it "returns a pipeline" do
      stub_request(:get, url)
        .with(headers: {"Authorization" => "Bearer access_token"})
        .to_return(status: 200, body: pipeline.to_json, headers: {"Content-Type" => "application/json"})

      expect(api.get_pipeline(project_id, pipeline_id, {id: :id, status: :status})).to eq(pipeline.with_indifferent_access)
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
          body: {assignee_ids: [assignee_id]}.to_json,
          headers: {
            "Authorization" => "Bearer access_token",
            "Content-Type" => "application/json; charset=utf-8"
          }
        )
        .to_return(status: 200, body: "", headers: {})

      expect(api.assign_pr(project_id, pr_number, assignee_id)).to be_truthy
    end
  end

  describe "#cherry_pick_pr" do
    let(:project_id) { "123" }
    let(:branch_name) { "main" }
    let(:patch_branch_name) { "cherry-pick-branch" }
    let(:commit_sha) { "abc1234" }
    let(:pr_title_prefix) { "Cherry-pick" }
    let(:pr_description) { "Description" }
    let(:transforms) { {id: :id} }
    let(:cherry_pick_url) { "https://gitlab.com/api/v4/projects/#{project_id}/repository/commits/#{commit_sha}/cherry_pick" }
    let(:create_branch_url) { "https://gitlab.com/api/v4/projects/#{project_id}/repository/branches" }
    let(:create_pr_url) { "https://gitlab.com/api/v4/projects/#{project_id}/merge_requests" }

    it "cherry-picks a pull request" do
      stub_request(:post, create_branch_url)
        .with(
          body: {branch: patch_branch_name, ref: branch_name}.to_json,
          headers: {
            "Authorization" => "Bearer access_token",
            "Content-Type" => "application/json; charset=utf-8"
          }
        )
        .to_return(status: 201, body: "", headers: {})

      stub_request(:post, cherry_pick_url)
        .with(
          body: {branch: patch_branch_name}.to_json,
          headers: {
            "Authorization" => "Bearer access_token",
            "Content-Type" => "application/json; charset=utf-8"
          }
        )
        .to_return(status: 201, body: {id: 1}.to_json, headers: {"Content-Type" => "application/json"})

      stub_request(:post, create_pr_url)
        .with(
          body: {source_branch: patch_branch_name, target_branch: branch_name, title: "#{pr_title_prefix} #{commit_sha}", description: pr_description}.to_json,
          headers: {
            "Authorization" => "Bearer access_token",
            "Content-Type" => "application/json; charset=utf-8"
          }
        )
        .to_return(status: 201, body: {id: 1}.to_json, headers: {"Content-Type" => "application/json"})

      stub_request(:get, "https://gitlab.com/api/v4/projects/#{project_id}/repository/compare?from=#{branch_name}&straight=false&to=#{patch_branch_name}")
        .with(headers: {"Authorization" => "Bearer access_token"})
        .to_return(status: 200, body: {diffs: [{}]}.to_json, headers: {"Content-Type" => "application/json"})

      expect(api.cherry_pick_pr(project_id, branch_name, commit_sha, patch_branch_name, pr_title_prefix, pr_description, transforms)).to be_truthy
    end

    context "when cherry-pick conflicts" do
      it "raises an error" do
        stub_request(:post, create_branch_url)
          .with(
            body: {branch: patch_branch_name, ref: branch_name}.to_json,
            headers: {
              "Authorization" => "Bearer access_token",
              "Content-Type" => "application/json; charset=utf-8"
            }
          )
          .to_return(status: 201, body: "", headers: {})

        stub_request(:post, cherry_pick_url)
          .with(
            body: {branch: patch_branch_name}.to_json,
            headers: {
              "Authorization" => "Bearer access_token",
              "Content-Type" => "application/json; charset=utf-8"
            }
          )
          .to_return(status: 400, body: {"message" => "Cherry-pick failed due to conflicts"}.to_json, headers: {"Content-Type" => "application/json"})

        expect { api.cherry_pick_pr(project_id, branch_name, commit_sha, patch_branch_name, pr_title_prefix, pr_description, transforms) }.to raise_error(Installations::Gitlab::Error)
      end
    end

    context "when branch already exists" do
      it "raises an error" do
        stub_request(:post, create_branch_url)
          .with(
            body: {branch: patch_branch_name, ref: branch_name}.to_json,
            headers: {
              "Authorization" => "Bearer access_token",
              "Content-Type" => "application/json; charset=utf-8"
            }
          )
          .to_return(status: 400, body: {"message" => "Branch already exists"}.to_json, headers: {"Content-Type" => "application/json"})

        expect { api.cherry_pick_pr(project_id, branch_name, commit_sha, patch_branch_name, pr_title_prefix, pr_description, transforms) }.to raise_error(Installations::Gitlab::Error)
      end
    end
  end
end
