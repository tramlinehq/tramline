module ReleasesHelper
  def approval_emoji(status)
    case status
    when "approved"
      "✅"
    when "rejected"
      "❌"
    when "pending"
      "⌛"
    end
  end

  def build_status_badge(status)
    display_data =
      case status
      when Releases::Step::Run.statuses[:on_track]
        ["In Progress", %w[bg-sky-100 text-sky-600]]
      when Releases::Step::Run.statuses[:success]
        ["Success", %w[bg-green-100 text-green-600]]
      when Releases::Step::Run.statuses[:failed]
        ["Failure", %w[bg-rose-100 text-rose-600]]
      when Releases::Step::Run.statuses[:halted]
        ["Cancelled", %w[bg-yellow-100 text-yellow-600]]
      else
        ["Unknown", %w[bg-slate-100 text-slate-500]]
      end

    classes = %w[text-xs uppercase tracking-wide inline-flex font-medium rounded-full text-center px-2 py-0.5]

    content_tag(
      :span,
      display_data.first,
      class: classes.concat(display_data.second)
    )
  end
end
