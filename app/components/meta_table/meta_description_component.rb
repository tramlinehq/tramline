class MetaTable::MetaDescriptionComponent < ViewComponent::Base
  def initialize(term)
    @term = term
  end

  attr_reader :term
end
