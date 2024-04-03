class StatCardComponent < V2::BaseComponent
  renders_one :icon, V2::IconComponent
  TYPES = [:empty, :stat]

  def initialize(name, type: :stat, external_url: nil, external_url_title: nil, empty_stat_help_text: nil)
    raise ArgumentError, "type must be one of #{TYPES}" unless TYPES.include?(type)
    raise ArgumentError, "you must provide a url text if external_url is supplied" if type == :stat && external_url.present? && external_url_title.blank?
    raise ArugmentError, "you must provide a help text if type is empty" if type == :empty && empty_stat_help_text.blank?

    @name = name
    @type = type
    @external_url = external_url
    @external_url_title = external_url_title
    @empty_stat_help_text = empty_stat_help_text
  end

  attr_reader :name, :external_url, :external_url_title

  def empty_stat?
    @type == :empty
  end

  def empty_stat_corner_icon
    if empty_stat? && @empty_stat_help_text.present?
      icon = V2::IconComponent.new("v2/info.svg", size: :md, classes: "text-main-500")

      icon.with_tooltip(@empty_stat_help_text, placement: "top", type: :detailed) do |tooltip|
        tooltip.with_detailed_text do
          content_tag(:div, nil, class: "flex flex-col gap-y-4 items-start") do
            concat simple_format(@empty_stat_help_text)
          end
        end
      end

      icon
    end
  end
end
