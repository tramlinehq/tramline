# frozen_string_literal: true

class V2::TableComponent < ViewComponent::Base
  renders_one :heading
  renders_many :rows, ->(style: "") { RowComponent.new(style: style) }

  def initialize(columns:)
    @columns = columns
  end

  attr_reader :columns

  class RowComponent < V2::BaseComponent
    renders_many :cells, ->(style: "") { CellComponent.new(style: style) }
    ROW_STYLE = "border-b dark:bg-gray-800 dark:border-gray-700"

    def initialize(style: "")
      @style = style
    end

    def call
      content_tag :tr, content, {class: ROW_STYLE + " #{@style}"} do
        cells.each do |cell|
          concat cell
        end
      end
    end

    class CellComponent < V2::BaseComponent
      CELL_STYLE = "px-4 py-2 whitespace-nowrap"

      def initialize(style: "")
        @style = style
      end

      def call
        content_tag :td, content, {class: CELL_STYLE + " #{@style}"}
      end
    end
  end
end
