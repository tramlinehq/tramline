# frozen_string_literal: true

class CustomParametersComponent < ViewComponent::Base
  attr_reader :form, :parameter_name_label, :parameter_value_label

  renders_one :add_button, ButtonComponent
  renders_one :heading
  renders_many :fields

  def initialize(form, parameter_name_label: "Parameter Name", parameter_value_label: "Parameter Value", trash_button: true)
    @form = form
    @parameter_name_label = parameter_name_label
    @parameter_value_label = parameter_value_label
    @trash_button = trash_button
  end
end
