# frozen_string_literal: true

class Form::SwitchComponent < ViewComponent::Base
  renders_one :child
  renders_one :heading
  renders_one :description
  renders_one :info_icon, InfoIconComponent

  def initialize(form:, field_name:, on_label: "Enabled", off_label: "Disabled", hide_child: true, switch_id: nil, switch_data: {}, html_options: {})
    @form = form
    @field_name = field_name
    @on_label = on_label
    @off_label = off_label
    @hide_child = hide_child
    @switch_id = switch_id
    @switch_data = switch_data
    @html_options = html_options
  end

  attr_reader :form, :field_name, :on_label, :off_label

  def field_id
    return field_name.to_s unless @switch_id
    @switch_id
  end

  def hide_child
    "hidden" if @hide_child
  end

  def form_label
    opts = {class: "bg-slate-400"}
    opts[:for] = field_id if @switch_id

    form.label(field_id, opts) do
      content_tag(:span, nil, class: "bg-white shadow", aria: {hidden: true})
        .concat(content_tag(:span, nil, class: "sr-only"))
    end
  end

  def form_checkbox
    action = "toggle-switch#change"
    action += " #{@switch_data[:action]}" if @switch_data.fetch(:action, nil)
    data = {action:, toggle_switch_target: "checkbox"}
    data.merge!(@switch_data.except(:action))
    opts = {class: "sr-only", data:}
    opts.merge!(@html_options)
    opts[:id] = field_id if @switch_id

    form.check_box(field_name, opts, "true", "false")
  end
end
