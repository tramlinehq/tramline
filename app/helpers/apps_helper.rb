module AppsHelper
  def setup_instruction_color(is_completed)
    is_completed ? "bg-green-400" : "bg-blue-200"
  end

  def movement_status_color(status_summary)
    {
      in_progress: "bg-indigo-500 text-white",
      done: "bg-green-500 text-white",
      failed: "bg-red-500 text-white",
      not_started: "bg-slate-500 text-white"
    }.freeze[status_summary.key(true)]
  end
end
