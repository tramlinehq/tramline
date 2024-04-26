class FilterButtonComponent < ViewComponent::Base
  renders_one :body

  def initialize(on:, path:, method:, filter_params:, query_params: {}, name: nil)
    @name = name
    @on = on
    @path = path
    @http_method = method
    @filter_params = filter_params
    @query_params = query_params
  end

  attr_reader :path, :http_method, :name

  BASE_STYLES = "inline-flex items-center justify-center text-sm font-medium leading-5 rounded-full px-3 py-1 border "

  def styles
    if @on
      BASE_STYLES + "bg-slate-600 text-white border-slate-600"
    else
      BASE_STYLES + "bg-white text-slate-800 hover:border-slate-800 border-slate-300 shadow"
    end
  end

  def button_params
    @on ? @query_params.except(*@filter_params.keys) : @query_params.merge(@filter_params)
  end
end
