class AddSupportAndMarketingUrlToReleaseMetadata < ActiveRecord::Migration[7.2]
  def change
    add_column :release_metadata, :support_url, :text
    add_column :release_metadata, :marketing_url, :text
    add_column :release_metadata, :draft_support_url, :text
    add_column :release_metadata, :draft_marketing_url, :text
  end
end
