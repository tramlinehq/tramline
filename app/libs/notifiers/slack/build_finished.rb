class Notifiers::Slack::BuildFinished
  ROOT_PATH = Rails.root.join("app/views/notifiers/slack")
  TEMPLATE_FILE = "build_finished.json.erb".freeze
  RUN_URI =
    Addressable::Template.new("https://api.github.com/repos/{org_name}/{repo_name}/actions/runs/{run_id}/artifacts")

  def self.render_json(**args)
    new(**args).render_json
  end

  def initialize(artifact_link:, code_name:, build_number:, version_number:, branch_name:)
    @artifact_link = artifact_link(artifact_link)
    @code_name = code_name
    @build_number = build_number
    @version_number = version_number
    @branch_name = branch_name

    @template = template_file
  end

  def render_json
    JSON.parse(render)
  end

  def render
    ERB.new(@template).result(binding)
  end

  private

  def artifact_link(link)
    extracted = RUN_URI.extract(link)
    "https://github.com/#{extracted['org_name']}/#{extracted['repo_name']}/actions/runs/#{extracted['run_id']}"
  end

  def template_file
    File.read(File.join(ROOT_PATH, TEMPLATE_FILE))
  end
end
