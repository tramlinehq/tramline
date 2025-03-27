module Installations
  class Github::MockClient
    def branch(repo, branch_name)
      # Return a dummy response similar to what Octokit would return
      {name: branch_name, commit: {sha: "dummy_sha"}}
    end

    def ref(repo, ref_name)
      # Return a dummy ref response
      {object: {sha: "dummy_sha", type: "commit"}}
    end

    def create_ref(repo, ref_name, sha)
      # Return a successful creation response
      {ref: ref_name, url: "https://github.com/#{repo}/#{ref_name}"}
    end

    def list_app_installation_repositories
      # Dummy response for repositories
      {
        repositories: [
          {name: "demo-repo", full_name: "demo-org/demo-repo"}
        ]
      }
    end

    def workflows(repo, options)
      {
        workflows: [
          {id: 1, name: "Build", state: "active"},
          {id: 2, name: "Deploy", state: "active"}
        ]
      }
    end

    def create_release(repo, tag_name, options)
      {tag_name: tag_name, html_url: "https://github.com/#{repo}/releases/tag/#{tag_name}"}
    end

    def compare(repo, from_branch, to_branch)
      {
        commits: [{sha: "dummy_sha", commit: {message: "Dummy commit"}}],
        files: [{filename: "dummy_file.txt", status: "modified"}]
      }
    end

    def merge_pull_request(repo, pr_number)
      {merged: true, sha: "dummy_sha", message: "Merged successfully"}
    end

    def pull_request(repo, pr_number)
      {id: pr_number, state: "open", title: "Dummy PR"}
    end
  end
end
