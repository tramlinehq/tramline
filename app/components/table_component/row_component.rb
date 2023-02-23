class TableComponent::RowComponent < ViewComponent::Base
  renders_many :cells, "CellComponent"

  class CellComponent < ViewComponent::Base
    def call
      content_tag :td, content, {class: "p-2.5 whitespace-nowrap"}
    end
  end
end
