class Notifiers::Slack::Renderers::Base
  include Rails.application.routes.url_helpers

  ROOT_PATH = Rails.root.join("app", "views", "notifiers", "slack")

  def self.render_json(**args)
    new(**args).render_json
  end

  def initialize(**args)
    @template_file = template_file
  end

  def render_json
    JSON.parse(render)
  end

  def render
    ERB.new(@template_file).result(binding)
  end

  def template_file
    File.read(File.join(ROOT_PATH, self.class::TEMPLATE_FILE))
  end
end
