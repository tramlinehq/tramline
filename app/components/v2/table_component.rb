# frozen_string_literal: true

class V2::TableComponent < ViewComponent::Base
  renders_one :heading
  renders_many :rows, ->(style: "") { RowComponent.new(style: style) }

  def initialize(columns:)
    @columns = columns
  end

  attr_reader :columns

  class RowComponent < V2::BaseComponent
    renders_many :cells, ->(style: "", wrap: false) { CellComponent.new(style:, wrap:) }
    ROW_STYLE = "border-default-b"

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
      CELL_STYLE = "px-4 py-2"

      def initialize(style: "", wrap: false)
        @style = style
        @wrap = wrap
      end

      def call
        content_tag :td, content, {class: CELL_STYLE + " #{@style} #{wrap_style}".squish}
      end

      def wrap_style
        "whitespace-nowrap" unless @wrap
      end
    end
  end
end
