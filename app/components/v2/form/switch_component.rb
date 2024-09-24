# frozen_string_literal: true

class V2::Form::SwitchComponent < ViewComponent::Base
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

  def switch_id # TODO: remove this after ensuring notifications form works
    return field_name.to_s + "-switch" unless @switch_id
    @switch_id
  end

  def hide_child
    "hidden" if @hide_child
  end

  def switch_options
    {class: "sr-only", data: switch_data}.merge(@html_options)
  end

  def data_actions
    val = "toggle-switch#change"
    val += " #{@switch_data[:action]}" if @switch_data.fetch(:action, nil)
    val
  end

  def switch_data
    {action: data_actions,
     toggle_switch_target: "checkbox"}.merge(@switch_data.except(:action))
  end

  def form_label
    form.label field_name, class: "bg-slate-400" do
      content_tag(:span, nil, class: "bg-white shadow", aria: {hidden: true})
        .concat(content_tag(:span, nil, class: "sr-only"))
    end
  end

  def form_checkbox
    form.check_box field_name, switch_options, "true", "false"
  end
end
