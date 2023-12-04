class AddAppVariantToStep < ActiveRecord::Migration[7.0]
  def change
    add_column :steps, :app_variant_id, :uuid, null: true
  end
end
