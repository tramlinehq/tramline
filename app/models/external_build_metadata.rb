# == Schema Information
#
# Table name: external_build_metadata
#
#  id          :uuid             not null, primary key
#  added_at    :datetime         not null
#  metadata    :jsonb            not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  step_run_id :uuid             not null, indexed, indexed
#
class ExternalBuildMetadata < ApplicationRecord
  has_paper_trail

  self.table_name = "external_build_metadata"

  METADATA_SCHEMA = Rails.root.join("config/schema/external_build_metadata.json")

  belongs_to :step_run, inverse_of: :external_build_metadata

  def update_or_insert!(new_metadata)
    validate_metadata_schema(new_metadata)
    return unless valid?

    ExternalBuildMetadata.upsert_all(
      [attributes_for_upsert(new_metadata)],
      unique_by: [:step_run_id],
      on_duplicate: Arel.sql("metadata = COALESCE(external_build_metadata.metadata, '{}'::jsonb) || COALESCE(EXCLUDED.metadata, '{}'::jsonb), added_at = CURRENT_TIMESTAMP")
    ).rows.first.first.then { |id| ExternalBuildMetadata.find_by(id: id) }
  end

  def attributes_for_upsert(new_metadata)
    {added_at: Time.current,
     metadata: new_metadata.index_by { |item| item[:identifier] },
     step_run_id: step_run_id}
  end

  def validate_metadata_schema(new_metadata)
    schemer = JSONSchemer.schema(METADATA_SCHEMA)
    unless schemer.valid?(new_metadata)
      errors.add(:metadata, "does not match the expected schema")
    end
  end
end
