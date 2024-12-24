class AddConfigTagPrefixToTrain < ActiveRecord::Migration[7.2]
  def change
    add_column :trains, :tag_prefix, :string
  end
end
