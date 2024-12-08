class Notifiers::Slack::Renderers::Base
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::JavaScriptHelper

  NOTIFIERS_RELATIVE_PATH = "app/views/notifiers/slack".freeze
  ROOT_PATH = Rails.root.join(NOTIFIERS_RELATIVE_PATH)
  HEADER_TEMPLATE = "header.json.erb".freeze
  FOOTER_TEMPLATE = "footer.json.erb".freeze
  FOOTER_V2_TEMPLATE = "footer_v2.json.erb".freeze

  def self.render_json(**args)
    new(**args).render_json
  end

  def initialize(**args)
    args.each do |key, value|
      instance_variable_set(:"@#{key}", value)
      self.class.send(:attr_accessor, key)
    end

    @template_file = template_file
  end

  def render_json
    header_response = JSON.parse(render_header)
    specific_data = JSON.parse(render_notification)
    footer_response = JSON.parse(render_footer)

    {blocks: header_response["blocks"].concat(specific_data["blocks"]).concat(footer_response["blocks"])}
  end

  def render_header
    file = File.read(File.join(ROOT_PATH, "header.json.erb"))
    ERB.new(file).result(binding)
  end

  def render_notification
    ERB.new(@template_file).result(binding)
  end

  def render_footer
    file = File.read(File.join(ROOT_PATH, @is_v2 ? FOOTER_V2_TEMPLATE : FOOTER_TEMPLATE))
    ERB.new(file).result(binding)
  end

  def template_file
    File.read(File.join(ROOT_PATH, self.class::TEMPLATE_FILE))
  end

  def safe_string(s) = escape_javascript(s)

  def google_managed_publishing_text
    "- If managed publishing is disabled, this update will auto-start the rollout upon approval by Google."
  end

  def google_unmanaged_publishing_text
    "- If managed publishing is enabled, you'll need to manually release this update through the Play Store."
  end

  def apple_publishing_text
    "- Releases from Tramline are always manually released, you can start the release to users once it is approved from the Live Release page."
  end
end
