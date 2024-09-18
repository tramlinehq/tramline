# frozen_string_literal: true

class V2::Form::SwitchComponent < ViewComponent::Base
  renders_one :child
  renders_one :heading
  renders_one :description

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

  def switch_id
    return field_name.to_s + "-switch" unless @switch_id
    @switch_id
  end

  def hide_child
    "hidden" if @hide_child
  end

  def switch_options
    {id: switch_id,
     class: "sr-only",
     data: switch_data}.merge(@html_options)
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
end
