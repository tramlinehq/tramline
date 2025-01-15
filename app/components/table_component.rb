# frozen_string_literal: true

class TableComponent < BaseComponent
  SIZES = %i[default compact].freeze

  renders_one :heading
  renders_many :rows, ->(style: "") { RowComponent.new(size: @size, style:) }

  def initialize(columns:, size: :default)
    raise ArgumentError, "Invalid size: #{size}" unless SIZES.include?(size)

    @columns = columns
    @size = size
  end

  attr_reader :columns

  def default?
    @size == :default
  end

  def compact?
    @size == :compact
  end

  def padding_x
    default? ? "px-4" : "px-2"
  end

  def padding_b
    default? ? "pb-3" : "pb-1.5"
  end

  def text_size
    default? ? "text-sm" : "text-xs"
  end

  class RowComponent < BaseComponent
    renders_many :cells, ->(style: "", wrap: false) { CellComponent.new(style:, wrap:, size: @size) }
    ROW_STYLE = "border-default-b"

    def initialize(size:, style:)
      @style = style
      @size = size
    end

    def call
      content_tag :tr, content, {class: ROW_STYLE + " #{@style}"} do
        cells.each do |cell|
          concat cell
        end
      end
    end

    class CellComponent < BaseComponent
      DEFAULT_CELL_STYLE = "px-4 py-2"
      COMPACT_CELL_STYLE = "px-2 py-1"

      def initialize(size:, style: "", wrap: false)
        @style = style
        @wrap = wrap
        @size = size
      end

      def call
        content_tag :td, content, {class: cell_style + " #{@style} #{wrap_style}"}
      end

      def cell_style
        default? ? DEFAULT_CELL_STYLE : COMPACT_CELL_STYLE
      end

      def default?
        @size == :default
      end

      def wrap_style
        "whitespace-nowrap" unless @wrap
      end
    end
  end
end
