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
    SELECT_CLASSES = "bg-main-50 border border-main-300 text-main-900 text-sm rounded-lg focus:ring-primary-500 focus:border-primary-500 block w-full p-2.5 dark:bg-main-700 dark:border-main-600 dark:placeholder-main-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"
    TEXT_AREA_CLASSES = "block p-2.5 w-full text-sm text-main-900 bg-main-50 rounded-lg border border-main-300 focus:ring-primary-500 focus:border-primary-500 dark:bg-main-700 dark:border-main-600 dark:placeholder-main-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"
    TEXT_FIELD_CLASSES = "bg-main-50 border border-main-300 text-main-900 text-sm rounded-lg focus:ring-primary-600 focus:border-primary-600 block w-full p-2.5 dark:bg-main-700 dark:border-main-600 dark:placeholder-main-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"
    DISABLED_CLASSES = "disabled:border-main-200 disabled:bg-main-100 disabled:text-main-600 disabled:cursor-not-allowed"

    def authz_submit(label, icon, scheme: :default, size: :sm, html_options: {})
      button_component =
        V2::ButtonComponent.new(scheme: scheme, type: :button, size: size, label: label, html_options: html_options)
      button_component.with_icon(icon)
      @template.render(button_component)
    end

    def label_only(method, label_text)
      label(method, label_text, class: LABEL_CLASSES)
    end

    def text_field_without_label(method, placeholder, options = {})
      hopts = { class: field_classes(is_disabled: options[:disabled], classes: TEXT_FIELD_CLASSES), placeholder: }.merge(options)
      text_field(method, hopts)
    end

    def select_without_label(method, select_options, options = {}, html_options = {})
      hopts = { class: field_classes(is_disabled: html_options[:disabled], classes: SELECT_CLASSES) }.merge(html_options)
      select(method, select_options, options, hopts)
    end

    def number_field_without_label(method, options = {})
      hopts = { class: field_classes(is_disabled: options[:disabled], classes: TEXT_FIELD_CLASSES), placeholder: 0 }.merge(options)
      number_field(method, hopts)
    end

    def labeled_text_field(method, label_text, options = {})
      label_only(method, label_text) + text_field_without_label(method, "Enter #{label_text.downcase}", options)
    end

    def labeled_number_field(method, label_text, options = {})
      hopts = { class: field_classes(is_disabled: options[:disabled], classes: TEXT_FIELD_CLASSES) }.merge(options)
      label_only(method, label_text) + number_field_without_label(method, hopts)
    end

    def labeled_select(method, label_text, select_options, options = {}, html_options = {})
      label_only(method, label_text) + select_without_label(method, select_options, options, html_options)
    end

    def labeled_tz_select(method, label_text, select_options, options = {}, html_options = {})
      opts = { class: field_classes(is_disabled: html_options[:disabled], classes: SELECT_CLASSES) }.merge(html_options)
      label_only(method, label_text) + time_zone_select(method, select_options, options, opts)
    end

    def labeled_datetime_field(method, label_text, options = {})
      hopts = { class: field_classes(is_disabled: options[:disabled], classes: TEXT_FIELD_CLASSES) }.merge(options)
      label_only(method, label_text) + datetime_field(method, hopts)
    end

    def labeled_textarea(method, label_text, options = {})
      opts = { rows: 4,
               class: field_classes(is_disabled: options[:disabled], classes: TEXT_AREA_CLASSES),
               placeholder: "Write #{label_text.downcase} here" }.merge(options)
      label_only(method, label_text) + text_area(method, opts)
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
