class Notifiers::Slack::ReleaseStarted
  ROOT_PATH = File.join(Rails.root, "app", "views", "notifiers", "slack")
  TEMPLATE_FILE = "release_started.json.erb"

  def self.render_json(**args)
    new(**args).render_json
  end

  def initialize(train_name:, version_number:, branch_name:, commit_msg:)
    @train_name = train_name
    @version_number = version_number
    @branch_name = branch_name
    @commit_msg = commit_msg
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
