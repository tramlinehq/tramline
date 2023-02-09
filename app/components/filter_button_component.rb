class FilterButtonComponent < ViewComponent::Base
  renders_one :body

  def initialize(on:, path:, method:, params:, form_data:)
    @on = on
    @path = path
    @http_method = method
    @params = params
    @form_data = form_data
  end

  attr_reader :path, :http_method, :form_data

  BASE_STYLES = "inline-flex items-center justify-center text-sm font-medium leading-5 rounded-full px-3 py-1 border shadow-sm "

  def styles
    if @on
      BASE_STYLES + "bg-slate-600 text-white"
    else
      BASE_STYLES + "bg-white text-slate-800 hover:border-slate-800 border-slate-300"
    end
  end

  def params
    @on ? {} : @params
  end
end
