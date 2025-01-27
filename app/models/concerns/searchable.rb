module Searchable
  extend ActiveSupport::Concern

  included do
    include PgSearch::Model
  end

  class_methods do
    private

    def search_config
      {
        using: {
          tsearch: {
            prefix: true,
            any_word: true,
            highlight: {
              StartSel: "<mark>",
              StopSel: "</mark>"
            }

          }
        }
      }
    end
  end
end
