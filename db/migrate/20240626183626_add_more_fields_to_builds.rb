class AddMoreFieldsToBuilds < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_table :builds, bulk: true do |t|
        t.string :external_id
        t.string :external_name
        t.integer :size_in_bytes
        t.integer :sequence_number
        t.string :slack_file_id
      end
    end
  end
end
