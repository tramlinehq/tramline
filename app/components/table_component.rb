class TableComponent < ViewComponent::Base
  renders_one :header
  renders_many :rows, TableComponent::RowComponent

  def initialize(columns:)
    @columns = columns
  end

  attr_reader :columns
end
