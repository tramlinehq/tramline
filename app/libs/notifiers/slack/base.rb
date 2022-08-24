class Notifiers::Slack::Base
  ROOT_PATH = File.join(Rails.root, "app", "views", "notifiers", "slack")

  def self.render_json(**args)
    new(**args).render_json
  end

  def initialize(**args)
    @template = template_file
  end

  def render_json
    JSON.parse(render)
  end

  def render
    ERB.new(@template).result(binding)
  end
end
