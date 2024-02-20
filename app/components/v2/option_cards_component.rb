class V2::OptionCardsComponent < V2::BaseComponent
  REQUIRED_OPTIONS = %i[title icon opt_name opt_value]

  def initialize(form:, options:)
    raise ArgumentError, "form is required" unless form
    raise ArgumentError, "options must be an array" unless options.is_a?(Array)

    @form = form
    @options = identify(options)
  end

  attr_reader :form, :options

  def identify(opts)
    opts.map do |option|
      option[:id] = option[:title].parameterize
      option[:icon] = V2::IconComponent.new(option[:icon], size: :xl)
      option[:options] = {id: option[:id], class: "hidden peer", required: true}.merge(option[:options] || {})
      option
    end
  end
end
