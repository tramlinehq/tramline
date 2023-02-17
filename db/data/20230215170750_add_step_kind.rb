class AddStepKind < ActiveRecord::Migration[7.0]
  def up
    Releases::Train.all.each do |train|
      if train.steps.present?
        max_step_number = train.steps.map(&:step_number).max
        train.steps.where(step_number: max_step_number).first.update(kind: "release")
        train.steps.where(kind: nil).update_all("kind = 'review'")
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
