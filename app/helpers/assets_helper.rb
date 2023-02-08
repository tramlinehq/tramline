module AssetsHelper
  include SvgHelper

  def inline_svg(asset_name, classname: "svg-container")
    content_tag(:div, safe_svg(inline_file(asset_name)), class: classname)
  end

  private

  def inline_file(asset_name)
    if (asset = Rails.application.assets&.find_asset(asset_name))
      asset.source
    else
      asset_path = Rails.application.assets_manifest.assets[asset_name]
      Rails.root.join("public/assets/#{asset_path}").read
    end
  end
end
