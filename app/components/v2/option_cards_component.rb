class V2::OptionCardsComponent < ViewComponent::Base
  def initialize(form:, options:)
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
