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
    BASE_LABEL_CLASSES = "text-xs font-medium text-secondary dark:text-white leading-6 cursor-pointer"
    LABEL_CLASSES = "mb-2 #{BASE_LABEL_CLASSES}"
    SIDE_LABEL_CLASSES = "ms-2 #{BASE_LABEL_CLASSES}"
    BASE_FIELD_CLASSES = "bg-main-50 border border-main-300 text-main rounded-lg focus:ring-primary-600 focus:border-primary-600 w-full dark:bg-main-700 dark:border-main-600 dark:placeholder-main-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"
    SELECT_CLASSES = "bg-main-50 border border-main-300 text-main text-sm rounded-lg focus:ring-primary-500 focus:border-primary-500 w-full p-2.5 dark:bg-main-700 dark:border-main-600 dark:placeholder-main-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"
    COMPACT_SELECT_CLASSES = "#{SELECT_CLASSES} !py-1.5 !max-w-32"
    TEXT_AREA_CLASSES = "p-2.5 w-full text-sm text-main bg-main-50 rounded-lg border border-main-300 focus:ring-primary-500 focus:border-primary-500 dark:bg-main-700 dark:border-main-600 dark:placeholder-main-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"
    COMPACT_TEXT_FIELD_CLASSES = "#{BASE_FIELD_CLASSES} text-xs"
    TEXT_FIELD_CLASSES = "#{BASE_FIELD_CLASSES} p-2.5 text-sm"
    CHECK_BOX_CLASSES = "w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
    DISABLED_CLASSES = "disabled:border-main-200 disabled:bg-main-100 disabled:text-main-600 disabled:cursor-not-allowed"
    FILE_INPUT_CLASSES = "w-full text-sm text-main border border-gray-300 rounded-lg cursor-pointer bg-gray-50 dark:text-gray-400 focus:outline-none dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400"
    OPTION_CLASSES = "w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"

    def authz_submit(label, icon, scheme: :default, size: :sm, disabled: false, html_options: {}, authz: true)
      button_component =
        V2::ButtonComponent.new(scheme:, type: :action, size:, label:, html_options:, turbo: false, disabled:, authz:)
      button_component.with_icon(icon)
      @template.render(button_component)
    end

    def label_only(method, label_text, type: :default)
      classes = case type
      when :default
        LABEL_CLASSES
      when :side
        SIDE_LABEL_CLASSES
      when :base
        BASE_LABEL_CLASSES
      else
        raise ArgumentError, "Invalid label type"
      end
      label(method, label_text, class: classes)
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
      classes = options[:compact] ? COMPACT_TEXT_FIELD_CLASSES : TEXT_FIELD_CLASSES
      hopts = {class: field_classes(is_disabled: options[:disabled], classes:), placeholder: 0}.merge(options)
      number_field(method, hopts)
    end

    def labeled_text_field(method, label_text, options = {})
      if options[:hidden]
        text_field_without_label(method, "Enter #{label_text.downcase}", options)
      else
        label_only(method, label_text) + text_field_without_label(method, "Enter #{label_text.downcase}", options)
      end
    end

    def labeled_email_field(method, label_text, options = {})
      hopts = {class: field_classes(is_disabled: options[:disabled], classes: TEXT_FIELD_CLASSES), placeholder: "Enter #{label_text.downcase}"}.merge(options)
      label_only(method, label_text) + email_field(method, hopts)
    end

    def labeled_number_field(method, label_text, options = {})
      hopts = {class: field_classes(is_disabled: options[:disabled], classes: TEXT_FIELD_CLASSES)}.merge(options)
      label_only(method, label_text) + number_field_without_label(method, hopts)
    end

    def labeled_color_field(method, label_text, options = {})
      hopts = {class: field_classes(is_disabled: options[:disabled], classes: TEXT_FIELD_CLASSES)}.merge(options)
      label_only(method, label_text) + color_field(method, hopts)
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
      opts = {placeholder: "Write #{label_text.downcase} here"}.merge(options)
      label_only(method, label_text) + textarea(method, opts)
    end

    def textarea(method, options)
      opts = {rows: 4, class: field_classes(is_disabled: options[:disabled], classes: TEXT_AREA_CLASSES)}.merge(options)
      text_area(method, opts)
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
        @template.concat label_only(method, label_text, type: :side)
      end
    end

    def labeled_radio_option(method, value, label_text, options = {})
      hopts = {class: field_classes(is_disabled: options[:disabled], classes: OPTION_CLASSES)}.merge(options)
      @template.content_tag(:div, class: "flex items-center me-4") do
        @template.concat radio_button(method, value, hopts)
        @template.concat label_only("#{method}_#{value}", label_text, type: :side)
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
