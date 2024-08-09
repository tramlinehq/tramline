class AddUniqueIndexToProductionRelease < ActiveRecord::Migration[6.1]
  def change
    change_column_default :production_releases, :status, to: "inflight", from: "created"
    safety_assured do
      add_index :production_releases, [:release_platform_run_id, :status], unique: true, name: "index_unique_inflight_production_release", where: "status = 'inflight'"
      add_index :production_releases, [:release_platform_run_id, :status], unique: true, name: "index_unique_active_production_release", where: "status = 'active'"
      add_index :production_releases, [:release_platform_run_id, :status], unique: true, name: "index_unique_finished_production_release", where: "status = 'finished'"
    end
  end
end
