# frozen_string_literal: true

class ChangePassportToNewStampableTypes < ActiveRecord::Migration[7.0]
  def up
    changed_stampable_types = {
      "Releases::TrainGroup::Run" => "Release",
      "Releases::Step::Run" => "StepRun",
      "Releases::Commit" => "Commit",
      "Releases::Train::Run" => "ReleasePlatformRun"
    }

    Passport.where(stampable_type: changed_stampable_types.keys).each do |passport|
      passport.update!(stampable_type: changed_stampable_types[passport.stampable_type])
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
