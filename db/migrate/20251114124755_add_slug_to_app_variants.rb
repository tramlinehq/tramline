class AddSlugToAppVariants < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      add_column :app_variants, :slug, :string
      add_index :app_variants, :slug, unique: true
    end
  end
end
