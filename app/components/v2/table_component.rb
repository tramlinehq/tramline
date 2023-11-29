# frozen_string_literal: true

class V2::TableComponent < ViewComponent::Base
  renders_one :heading
  renders_many :rows, "RowComponent"

  class RowComponent < V2::BaseComponent
    renders_many :cells, "CellComponent"

    def call
      content_tag :tr, content, { class: "bg-white dark:bg-gray-900 border-b dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600" } do
        cells.each do |cell|
          concat cell
        end
      end
    end

    class CellComponent < V2::BaseComponent
      def call
        content_tag :td, content, { class: "px-6 py-4 whitespace-nowrap" }
      end
    end
  end

  def initialize(caption:, caption_text:, columns:)
    @caption = caption
    @caption_text = caption_text
    @columns = columns
  end

  attr_reader :caption, :caption_text, :columns
end
