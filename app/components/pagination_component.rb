class PaginationComponent < ViewComponent::Base
  include Pagy::Frontend

  attr_reader :results, :turbo_frame

  def initialize(results:, turbo_frame:, info: false)
    @results = results
    @info = info
    @turbo_frame = turbo_frame
  end

  def info?
    @info
  end
end
