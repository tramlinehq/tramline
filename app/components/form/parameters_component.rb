# frozen_string_literal: true

class Form::ParametersComponent < ViewComponent::Base
  attr_reader :form, :parameter_name_label, :parameter_value_label

  def initialize(form, parameter_name_label: "Parameter Name", parameter_value_label: "Parameter Value", trash_button: true)
    @form = form
    @parameter_name_label = parameter_name_label
    @parameter_value_label = parameter_value_label
    @trash_button = trash_button
  end

  def trash_button? = @trash_button
end
