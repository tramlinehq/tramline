module EnhancedFormHelper
  class BetterForm < ActionView::Helpers::FormBuilder
    def mandatory_label(method, *args)
      options = args.extract_options!
      text = args.first

      asterisk_span = @template.content_tag(:span, "*", class: "text-rose-500")
      label_text = text || method.to_s.humanize
      label_content = "#{label_text} #{asterisk_span}".html_safe
      label(method, label_content, options&.merge(required: true) || {})
    end
  end
end
