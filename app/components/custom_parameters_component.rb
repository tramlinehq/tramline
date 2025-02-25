# frozen_string_literal: true

class CustomParametersComponent < ViewComponent::Base
  attr_reader :form

  renders_one :add_button, ButtonComponent
  renders_one :trash_button, ButtonComponent
  renders_one :heading

  renders_many :edit_fields
  renders_many :add_fields

  def initialize(form)
    @form = form
  end
end
