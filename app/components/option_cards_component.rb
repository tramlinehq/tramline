class OptionCardsComponent < BaseComponent
  LABEL_CLASSES = "inline-flex items-center justify-between w-full p-3 text-secondary bg-white border border-main-200 rounded-lg cursor-pointer dark:hover:text-main-300 dark:border-main-700 dark:peer-checked:text-blue-700 peer-checked:border-blue-800 peer-checked:text-blue-800 hover:text-main-600 peer-checked:bg-main-100 hover:bg-main-100 dark:text-secondary-50 dark:bg-main-800 dark:peer-checked:bg-main-700 dark:hover:bg-main-700"
  DEFAULT_OPTS = {class: "hidden peer", required: true}

  def initialize(form:, options:)
    raise ArgumentError, "form is required" unless form
    raise ArgumentError, "options must be an array" unless options.is_a?(Array)

    @form = form
    @options = enhance_opts(options)
  end

  attr_reader :form, :options

  def enhance_opts(opts)
    opts.map do |option|
      base_id = [form.object_name, option[:opt_name]].compact_blank.join("_")
      base_id += "_#{option[:opt_value]}" if option[:opt_value]
      option[:id] = base_id
      option[:icon] = IconComponent.new(option[:icon], size: :xl)
      option[:options] = DEFAULT_OPTS.merge(option[:options] || {})
      option
    end
  end
end
