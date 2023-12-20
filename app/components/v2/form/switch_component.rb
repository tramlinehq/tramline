# frozen_string_literal: true

class V2::Form::SwitchComponent < ViewComponent::Base
  renders_one :child
  renders_one :heading
  renders_one :description

  def initialize(form:, field_name:, on_label: "Enabled", off_label: "Disabled", hide_child: true)
    @form = form
    @field_name = field_name
    @on_label = on_label
    @off_label = off_label
    @hide_child = hide_child
  end

  attr_reader :form, :field_name, :on_label, :off_label

  def switch_id
    field_name.to_s + "-switch"
  end

  def hide_child
    "hidden" if @hide_child
  end
end
