module SvgHelper
  def safe_svg(body)
    sanitize(body, tags: Loofah::HTML5::WhiteList::SVG_ELEMENTS, attributes: Loofah::HTML5::WhiteList::SVG_ATTRIBUTES)
  end
end
