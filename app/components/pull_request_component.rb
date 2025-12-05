class PullRequestComponent < ViewComponent::Base
  DEFAULT_TRUNCATE = 80

  def initialize(pull_request:, simple: false, render_html: false, enable_truncate: true)
    @pr = pull_request
    @simple = simple
    @render_html = render_html
    @enable_truncate = enable_truncate
  end

  attr_reader :pr, :simple, :render_html, :enable_truncate

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
    title = enable_truncate ? pr.title.truncate(DEFAULT_TRUNCATE) : pr.title
    render_html ? sanitize(title, tags: %w[mark span]) : title
  end
end
