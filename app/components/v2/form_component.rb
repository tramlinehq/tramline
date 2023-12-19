# frozen_string_literal: true

class V2::FormComponent < V2::BaseComponent
  renders_many :sections, V2::FormSectionComponent
  renders_many :advanced_sections, V2::FormSectionComponent

  def initialize(*)
    super
  end
end
