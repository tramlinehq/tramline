class PullRequestComponent < ViewComponent::Base
  def initialize(pull_request:, simple: false)
    @pr = pull_request
    @simple = simple
  end

  attr_reader :pr, :simple

  def status
    case @pr.state.to_sym
    when :open
      :success
    when :closed
      :ongoing
    else
      :neutral
    end
  end

  def state
    @pr.state.titleize
  end

  def style
    if simple
      "border-default rounded-sm"
    else
      "hover:bg-main-100 hover:border-main-100 hover:first:rounded-sm hover:last:rounded-sm"
    end
  end
end
