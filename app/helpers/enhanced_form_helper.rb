module EnhancedFormHelper
  include ButtonHelper

  class BetterForm < ActionView::Helpers::FormBuilder
    def mandatory_label(method, *args)
      options = args.extract_options!
      text = args.first

      asterisk_span = @template.content_tag(:span, "*", class: "text-rose-500 ml-1")
      label_text = text || method.to_s.humanize
      label_content = @template.safe_join([label_text, asterisk_span])
      label(method, label_content, options&.merge(required: true) || {})
    end
  end

  class AuthzForm < ActionView::Helpers::FormBuilder
    LABEL_CLASSES = "block mb-2 text-sm font-medium text-main-900 dark:text-white"
    SIDE_LABEL_CLASSES = "ms-2 text-sm font-medium text-main-900 dark:text-white"
    SELECT_CLASSES = "bg-main-50 border border-main-300 text-main-900 text-sm rounded-lg focus:ring-primary-500 focus:border-primary-500 block w-full p-2.5 dark:bg-main-700 dark:border-main-600 dark:placeholder-main-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"
    TEXT_AREA_CLASSES = "block p-2.5 w-full text-sm text-main-900 bg-main-50 rounded-lg border border-main-300 focus:ring-primary-500 focus:border-primary-500 dark:bg-main-700 dark:border-main-600 dark:placeholder-main-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"
    TEXT_FIELD_CLASSES = "bg-main-50 border border-main-300 text-main-900 text-sm rounded-lg focus:ring-primary-600 focus:border-primary-600 w-full p-2.5 dark:bg-main-700 dark:border-main-600 dark:placeholder-main-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"
    CHECK_BOX_CLASSES = "w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
    DISABLED_CLASSES = "disabled:border-main-200 disabled:bg-main-100 disabled:text-main-600 disabled:cursor-not-allowed"
    FILE_INPUT_CLASSES = "block w-full text-sm text-gray-900 border border-gray-300 rounded-lg cursor-pointer bg-gray-50 dark:text-gray-400 focus:outline-none dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400"
    OPTION_CLASSES = "w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"

    def authz_submit(label, icon, scheme: :default, size: :sm, html_options: {})
      button_component =
        V2::ButtonComponent.new(scheme: scheme, type: :action, size: size, label: label, html_options: html_options, turbo: false)
      button_component.with_icon(icon)
      @template.render(button_component)
    end

    def label_only(method, label_text)
      label(method, label_text, class: LABEL_CLASSES)
    end

    def text_field_without_label(method, placeholder, options = {})
      hopts = {class: field_classes(is_disabled: options[:disabled], classes: TEXT_FIELD_CLASSES), placeholder:}.merge(options)
      text_field(method, hopts)
    end

    def select_without_label(method, select_options, options = {}, html_options = {})
      hopts = {class: field_classes(is_disabled: html_options[:disabled], classes: SELECT_CLASSES)}.merge(html_options)
      select(method, select_options, options, hopts)
    end

    def number_field_without_label(method, options = {})
      hopts = {class: field_classes(is_disabled: options[:disabled], classes: TEXT_FIELD_CLASSES), placeholder: 0}.merge(options)
      number_field(method, hopts)
    end

    def labeled_text_field(method, label_text, options = {})
      label_only(method, label_text) + text_field_without_label(method, "Enter #{label_text.downcase}", options)
    end

    def labeled_number_field(method, label_text, options = {})
      hopts = {class: field_classes(is_disabled: options[:disabled], classes: TEXT_FIELD_CLASSES)}.merge(options)
      label_only(method, label_text) + number_field_without_label(method, hopts)
    end

    def labeled_select(method, label_text, select_options, options = {}, html_options = {})
      label_only(method, label_text) + select_without_label(method, select_options, options, html_options)
    end

    def labeled_tz_select(method, label_text, select_options, options = {}, html_options = {})
      opts = {class: field_classes(is_disabled: html_options[:disabled], classes: SELECT_CLASSES)}.merge(html_options)
      label_only(method, label_text) + time_zone_select(method, select_options, options, opts)
    end

    def labeled_datetime_field(method, label_text, options = {})
      hopts = {class: field_classes(is_disabled: options[:disabled], classes: TEXT_FIELD_CLASSES)}.merge(options)
      label_only(method, label_text) + datetime_field(method, hopts)
    end

    def labeled_textarea(method, label_text, options = {})
      opts = {rows: 4,
              class: field_classes(is_disabled: options[:disabled], classes: TEXT_AREA_CLASSES),
              placeholder: "Write #{label_text.downcase} here"}.merge(options)
      label_only(method, label_text) + text_area(method, opts)
    end

    def labeled_file_field(method, label_text, help_text = nil, options = {})
      opts = {class: field_classes(is_disabled: options[:disabled], classes: FILE_INPUT_CLASSES)}.merge(options)
      output = label_only(method, label_text) + file_field(method, opts)
      output += @template.content_tag(:p, help_text, class: "mt-1 text-sm text-gray-500 dark:text-gray-300") if help_text.present?
      output
    end

    def labeled_checkbox(method, label_text, options = {})
      hopts = {class: field_classes(is_disabled: options[:disabled], classes: CHECK_BOX_CLASSES)}.merge(options)
      @template.content_tag(:div, class: "flex items-center") do
        @template.concat check_box(method, hopts)
        @template.concat label(method, label_text, class: SIDE_LABEL_CLASSES)
      end
    end

    def labeled_radio_option(method, value, label_text, options = {})
      hopts = {class: field_classes(is_disabled: options[:disabled], classes: OPTION_CLASSES)}.merge(options)
      @template.content_tag(:div, class: "flex items-center me-4") do
        @template.concat radio_button(method, value, hopts)
        @template.concat label("#{method}_#{value}", label_text, class: SIDE_LABEL_CLASSES)
      end
    end

    private

    def field_classes(is_disabled:, classes:)
      if is_disabled
        "#{classes} #{DISABLED_CLASSES}".squish
      else
        classes
      end
    end
  end
end
