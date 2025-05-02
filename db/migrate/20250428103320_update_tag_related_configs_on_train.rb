class UpdateTagRelatedConfigsOnTrain < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      rename_column :trains, :tag_releases, :tag_end_of_release
      rename_column :trains, :tag_suffix, :tag_end_of_release_suffix
      rename_column :trains, :tag_prefix, :tag_end_of_release_prefix
      rename_column :trains, :tag_all_store_releases, :tag_store_releases
      rename_column :trains, :tag_platform_releases, :tag_store_releases_with_platform_names
      
      add_column :trains, :tag_end_of_release_vcs_release, :boolean, default: false
      add_column :trains, :tag_store_releases_vcs_release, :boolean, default: false
    end
  end
end
