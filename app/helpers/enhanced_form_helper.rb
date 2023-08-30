module EnhancedFormHelper
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
end
