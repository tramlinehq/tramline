# frozen_string_literal: true

class FillExternalReleaseExternalLink < ActiveRecord::Migration[7.0]
  def up
    app_store_external_link_template = Addressable::Template.new("https://appstoreconnect.apple.com/apps/{app_id}/testflight/ios/{external_id}")

    ExternalRelease.all.map do |external_release|
      if external_release.app_store_integration?
        external_release.update(external_link: app_store_external_link_template.expand(app_id: external_release.app.external_id, external_id: external_release.external_id))
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
