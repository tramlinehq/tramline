# frozen_string_literal: true

class ChangePassportToNewStampableTypes < ActiveRecord::Migration[7.0]
  class MigrationIntegrityFailed < StandardError; end

  def up
    ActiveRecord::Base.transaction do
      Passport.where(stampable_type: "Releases::Step::Run").each do |passport|
        next if StepRun.find_by(id: passport.stampable_id).blank?
        passport.update!(stampable_type: "StepRun")
      end

      Passport.where(stampable_type: "Releases::Commit").each do |passport|
        next if Commit.find_by(id: passport.stampable_id).blank?
        passport.update!(stampable_type: "Commit")
      end

      Passport.where(stampable_type: "Releases::Train::Run").each do |passport|
        stampable = ReleasePlatformRun.find_by(id: passport.stampable_id)
        next if stampable.blank?

        passport.update!(
          stampable_type: "Release",
          stampable_id: stampable.release.id
        )
      end

      total_passports = Passport.count

      result = Passport.all.map do |passport|
        passport.stampable.valid?
      rescue ActiveRecord::RecordNotFound, NameError
        passport.destroy!
        false
      end

      raise MigrationIntegrityFailed unless Passport.count + result.count { |element| !element.itself } == total_passports
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
