class AddIntegrationsToSteps < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_reference :steps, :integration, null: true, index: {algorithm: :concurrently}, type: :uuid
  end
end
