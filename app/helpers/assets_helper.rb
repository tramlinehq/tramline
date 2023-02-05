module AssetsHelper
  def inline_file(asset_name)
    if (asset = Rails.application.assets&.find_asset(asset_name))
      asset.source.html_safe
    else
      asset_path = Rails.application.assets_manifest.assets[asset_name]
      File.read(File.join(Rails.root, "public", "assets", asset_path)).html_safe
    end
  end

  def inline_js(asset_name)
    content_tag(:script, inline_file(asset_name), type: "text/javascript")
  end

  def inline_stylesheet(asset_name)
    content_tag(:style, inline_file(asset_name), type: "text/css")
  end

  def inline_svg(asset_name, classname: "svg-container")
    content_tag(:div, inline_file(asset_name), class: classname)
  end
end
