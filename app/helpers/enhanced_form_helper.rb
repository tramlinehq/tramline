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
    LABEL_CLASSES = "block mb-2 text-sm font-medium text-gray-900 dark:text-white"
    SELECT_CLASSES = "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-primary-500 focus:border-primary-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"
    TEXT_AREA_CLASSES = "block p-2.5 w-full text-sm text-gray-900 bg-gray-50 rounded-lg border border-gray-300 focus:ring-primary-500 focus:border-primary-500 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"
    TEXT_FIELD_CLASSES = "bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-primary-600 focus:border-primary-600 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-primary-500 dark:focus:border-primary-500"

    def authz_submit(label, icon)
      button_component = V2::ButtonComponent.new(scheme: :default, type: :button, size: :base, label: label)
      button_component.with_icon(icon)
      @template.render(button_component)
    end

    def label_only(method, label_text)
      label(method, label_text, class: LABEL_CLASSES)
    end

    def text_field_without_label(method, placeholder, options = {})
      text_field(method, {class: TEXT_FIELD_CLASSES, placeholder:, required: true}
                           .merge(options))
    end

    def labeled_text_field(method, label_text, options = {})
      label_only(method, label_text) + text_field_without_label(method, "Enter #{label_text.downcase}", options)
    end

    def labeled_number_field(method, label_text, options = {})
      label_only(method, label_text) +
        number_field(method, {class: TEXT_FIELD_CLASSES, placeholder: "Enter #{label_text.downcase}", required: true}
                               .merge(options))
    end

    def labeled_select(method, label_text, select_options, options = {}, html_options = {})
      label_only(method, label_text) +
        select(method, select_options, options, {class: SELECT_CLASSES}.merge(html_options))
    end

    def labeled_tz_select(method, label_text, select_options, options = {}, html_options = {})
      label_only(method, label_text) +
        time_zone_select(method, select_options, options, {class: SELECT_CLASSES}.merge(html_options))
    end

    def labeled_textarea(method, label_text, options = {})
      label_only(method, label_text) +
        text_area(method, {rows: 4, class: TEXT_AREA_CLASSES, placeholder: "Write #{label_text.downcase} here"}
                            .merge(options))
    end
  end
end
