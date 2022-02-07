class Notifiers::Slack::BuildFinished
  ROOT_PATH = File.join(Rails.root, "app", "views", "notifiers", "slack")
  TEMPLATE_FILE = "build_finished.json.erb"

  def self.render_json(**args)
    new(**args).render_json
  end

  def initialize(artifact_link:, code_name:, build_number:, version_number:, branch_name:)
    @artifact_link = artifact_link
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

  def template_file
    File.read(File.join(ROOT_PATH, TEMPLATE_FILE))
  end
end