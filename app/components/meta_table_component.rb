class MetaTableComponent < ViewComponent::Base
  renders_many :descriptions, MetaTable::MetaDescriptionComponent

  def bg_color(idx)
    idx.odd? ? "bg-white" : "bg-slate-50"
  end
end
