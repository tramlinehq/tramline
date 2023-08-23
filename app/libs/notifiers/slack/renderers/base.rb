class Notifiers::Slack::Renderers::Base
  include Rails.application.routes.url_helpers
  include DeploymentsHelper
  include ActionView::Helpers::JavaScriptHelper

  NOTIFIERS_RELATIVE_PATH = "app/views/notifiers/slack".freeze
  ROOT_PATH = Rails.root.join(NOTIFIERS_RELATIVE_PATH)

  def self.render_json(**args)
    new(**args).render_json
  end

  def initialize(**args)
    args.each do |key, value|
      instance_variable_set("@#{key}", value)
      self.class.send(:attr_accessor, key)
    end

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

  def deployment_channel_display_name
    return unless @deployment_channel
    deployment_channel_name(@deployment_channel)
  end

  def safe_string(s) = escape_javascript(s)
end
