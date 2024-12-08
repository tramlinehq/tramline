# == Schema Information
#
# Table name: external_builds
#
#  id          :uuid             not null, primary key
#  metadata    :jsonb            not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  build_id    :uuid             indexed
#  step_run_id :uuid             indexed
#
class ExternalBuild < ApplicationRecord
  has_paper_trail

  METADATA_SCHEMA = Rails.root.join("config/schema/external_build_metadata.json")

  self.ignored_columns += ["step_run_id"]

  belongs_to :build, inverse_of: :external_build, optional: true

  # rubocop:disable Rails/SkipsModelValidations
  def update_or_insert!(new_metadata)
    validate_metadata_schema(new_metadata)
    return self if errors.present?

    unique_by = [:build_id]

    ExternalBuild.upsert_all(
      [attributes_for_upsert(new_metadata)],
      unique_by: unique_by,
      on_duplicate: Arel.sql("metadata = COALESCE(external_builds.metadata, '{}'::jsonb) || COALESCE(EXCLUDED.metadata, '{}'::jsonb), updated_at = CURRENT_TIMESTAMP")
    ).rows.first.first.then { |id| ExternalBuild.find_by(id: id) }
  end
  # rubocop:enable Rails/SkipsModelValidations

  def attributes_for_upsert(new_metadata)
    {metadata: new_metadata.index_by { |item| item[:identifier] },
     build_id: build_id}
  end

  def validate_metadata_schema(new_metadata)
    JSON::Validator.validate!(METADATA_SCHEMA.to_s, new_metadata)
  rescue JSON::Schema::ValidationError => e
    errors.add(:metadata, e.message)
  end

  def normalized_metadata
    metadata.map { NormalizedMetadata.new(_2) }
  end

  class NormalizedMetadata
    def initialize(metadata)
      @metadata = metadata
    end

    def identifier = metadata["identifier"]

    def value = metadata["value"]

    def unit = metadata["unit"]

    def description = metadata["description"]

    def type = metadata["type"]

    def name = metadata["name"]

    def numerical?
      type == "number"
    end

    def textual?
      type == "string"
    end

    private

    attr_reader :metadata
  end
end
