class AddNeedsReauthStatusToIntegrations < ActiveRecord::Migration[7.0]
  def up
    safety_assured do
      # First, add the new enum value to the check constraint
      execute <<-SQL
      ALTER TABLE integrations
      DROP CONSTRAINT IF EXISTS chk_rails_status_enum;

      ALTER TABLE integrations
      ADD CONSTRAINT chk_rails_status_enum
      CHECK (status IN ('connected', 'disconnected', 'needs_reauth'));
      SQL
    end
  end

  def down
    safety_assured do
      # Remove any integrations that have the needs_reauth status
      execute "UPDATE integrations SET status = 'disconnected' WHERE status = 'needs_reauth';"

      # Restore the original constraint
      execute <<-SQL
      ALTER TABLE integrations
      DROP CONSTRAINT IF EXISTS chk_rails_status_enum;

      ALTER TABLE integrations
      ADD CONSTRAINT chk_rails_status_enum
      CHECK (status IN ('connected', 'disconnected'));
      SQL
    end
  end
end
