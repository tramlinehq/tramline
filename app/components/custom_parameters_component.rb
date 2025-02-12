# frozen_string_literal: true

class CustomParametersComponent < ViewComponent::Base
  attr_reader :form, :parameter_name_label, :parameter_value_label

  def initialize(form, parameter_name_label: "Parameter Name", parameter_value_label: "Parameter Value", add_button: true, trash_button: true)
    @form = form
    @parameter_name_label = parameter_name_label
    @parameter_value_label = parameter_value_label
    @add_button = add_button
    @trash_button = trash_button
  end

  def add_button? = @add_button
end
