# frozen_string_literal: true

class V2::FormComponent < V2::BaseComponent
  renders_many :sections, V2::Form::SectionComponent
  renders_many :advanced_sections, V2::Form::SectionComponent

  def initialize(*)
    super
  end
end
