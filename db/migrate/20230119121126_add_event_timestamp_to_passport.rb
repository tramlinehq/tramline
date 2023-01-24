class AddEventTimestampToPassport < ActiveRecord::Migration[7.0]
  def change
    add_column :passports, :event_timestamp, :datetime

    safety_assured do
      execute <<-SQL.squish
        UPDATE passports SET event_timestamp = created_at
      SQL

      change_column_null :passports, :event_timestamp, false
    end
  end
end
