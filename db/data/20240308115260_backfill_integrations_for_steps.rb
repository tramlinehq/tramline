class BackfillIntegrationsForSteps < ActiveRecord::Migration[7.0]
  def up
    return
    Step.find_each do |step|
      next if step.integration.present?
      ci_cd_integration = step.train.integrations.where(category: "ci_cd").first
      next if ci_cd_integration.blank?
      step.update!(integration: ci_cd_integration)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
