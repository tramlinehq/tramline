class V2::Reldex::CalculationTableComponent < V2::Reldex::BaseComponent
  def initialize(tolerable_min:, tolerable_max:)
    @tolerable_min = tolerable_min
    @tolerable_max = tolerable_max
  end

  attr_reader :tolerable_min, :tolerable_max
end
