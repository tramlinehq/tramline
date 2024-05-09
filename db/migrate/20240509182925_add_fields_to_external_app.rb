class AddFieldsToExternalApp < ActiveRecord::Migration[7.0]
  def change
    add_column :external_apps, :default_locale, :string
  end
end
