module Searchable
  extend ActiveSupport::Concern

  included do
    include PgSearch::Model
  end

  class_methods do
    def generate_search_vector(text)
      connection.execute(<<~SQL.squish).first["to_tsvector"]
        SELECT to_tsvector('english', #{connection.quote(text)})
      SQL
    end

    private

    def search_config
      {
        using: {
          tsearch: {
            prefix: true,
            any_word: true,
            dictionary: "english",
            tsvector_column: "search_vector",
            highlight: {
              StartSel: "<mark>",
              StopSel: "</mark>"
            }
          },
          trigram: {
            threshold: 0.3,
            word_similarity: true
          }
        },
        ranked_by: ":trigram + :tsearch"
      }
    end
  end
end
