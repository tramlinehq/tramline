class AddConfigToBugsnagIntegration < ActiveRecord::Migration[7.2]
  def change
    add_column :bugsnag_integrations, :android_config, :jsonb
    add_column :bugsnag_integrations, :ios_config, :jsonb
  end
end
