class StatCardComponent < BaseComponent
  renders_one :icon, IconComponent
  TYPES = [:empty, :stat]
  EMPTY_STAT_TEXT_SIZE = {
    compact: "text-base",
    default: "text-lg"
  }

  def initialize(name, size: :default, type: :stat, external_url: nil, external_url_title: nil, empty_stat_help_text: nil)
    raise ArgumentError, "type must be one of #{TYPES}" unless TYPES.include?(type)
    raise ArgumentError, "you must provide a url text if external_url is supplied" if type == :stat && external_url.present? && external_url_title.blank?
    raise ArugmentError, "you must provide a help text if type is empty" if type == :empty && empty_stat_help_text.blank?

    @name = name
    @size = size || :default
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
      icon = IconComponent.new("info.svg", size: :md, classes: "text-secondary")

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

  def empty_stat_text_size
    EMPTY_STAT_TEXT_SIZE[@size]
  end
end
