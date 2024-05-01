class V2::PullRequestComponent < ViewComponent::Base
  def initialize(pull_request:)
    @pr = pull_request
  end

  attr_reader :pr

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
end
