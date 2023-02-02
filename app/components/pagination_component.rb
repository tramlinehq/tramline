class PaginationComponent < ViewComponent::Base
  include Pagy::Frontend

  attr_reader :results, :turbo_frame

  def initialize(results:, turbo_frame:, info: false)
    @results = results
    @turbo_frame = turbo_frame
    @info = info
  end

  def info?
    @info
  end
end
