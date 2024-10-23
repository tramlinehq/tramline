class ApprovalsPresenter < SimpleDelegator
  include Memery

  STATUS = {
    not_started: {text: "Not started", notice: "", color: :neutral},
    in_progress: {text: "In progress", notice: "marked as started by", color: :ongoing},
    blocked: {text: "Blocked", notice: "marked as blocked by", color: :failure},
    approved: {text: "Approved", notice: "approved by", color: :success}
  }.with_indifferent_access

  INFO = "Release pilots can create approval items, and assign them to specific individuals to manage stakeholder approvals for the release.".freeze
  APPROVED_NOTICE = "No items with pending approvals. The release can move to the submission step.".freeze
  FORCE_APPROVED_NOTICE = "Approvals have been force-approved by the release pilot. The release can now move to the submission step.".freeze

  def self.sanitized_statuses
    STATUS.transform_values { |value| value[:text] }.invert
  end

  def self.available_assignee_options(available_assignees)
    available_assignees.map { |assignee| [assignee.preferred_name, assignee.id] }
  end

  def initialize(approval_item, view_context = nil)
    @view_context = view_context
    super(approval_item)
  end

  def assignee_avatar(assignee)
    h.user_avatar(assignee.preferred_name, limit: 2, size: 24, colors: 120)
  end

  def assignee_tooltip(assignee)
    "#{assignee.full_name} (#{assignee.email})"
  end

  def status_notice
    "#{STATUS[status][:notice]} #{status_changed_by.preferred_name}"
  end

  def status_color
    h.status_picker(ApplicationHelper::STATUS_COLOR_PALETTE, STATUS[status][:color]).join(" ")
  end

  def disabled?
    approved? || !allowed?
  end

  memoize def allowed?
    edit_allowed?(h.current_user)
  end

  def status_tooltip
    return "Not assigned to this item" unless allowed?
    "Item is approved and is now unmodifiable" if approved?
  end

  def h
    @view_context
  end
end
