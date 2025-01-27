class PullRequestComponent < ViewComponent::Base
  def initialize(pull_request:, simple: false, render_html: false)
    @pr = pull_request
    @simple = simple
    @render_html = render_html
  end

  attr_reader :pr, :simple, :render_html

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

  def truncated_title
    title = pr.title.truncate(80)
    render_html ? title.html_safe : title
  end
end
