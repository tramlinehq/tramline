module AssetsHelper
  def inline_svg(asset_name, classname: "svg-container")
    return if asset_name.blank?
    content_tag(:div, safe_svg(inline_file(asset_name)), class: classname)
  end

  # Builds the asset path for an integration provider's logo, falling back to a
  # generic "deprecated" logo when the provider is missing (e.g. the integration
  # was disconnected while releases still reference it). Avoids "logo_.png".
  def integration_logo(provider)
    "integrations/logo_#{provider.presence || "deprecated"}.png"
  end

  # Black-and-white variant of integration_logo. There is no deprecated bw asset,
  # so a missing provider falls back to the coloured deprecated logo.
  def integration_logo_bw(provider)
    return integration_logo(nil) if provider.blank?
    "logo_#{provider}_bw.svg"
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

  def safe_svg(body)
    sanitize(body, tags: Loofah::HTML5::WhiteList::SVG_ELEMENTS, attributes: Loofah::HTML5::WhiteList::SVG_ATTRIBUTES)
  end
end
