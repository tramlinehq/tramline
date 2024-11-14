class ApprovalItemsController < SignedInApplicationController
  include Tabbable

  before_action :require_write_access!, except: [:index, :update]
  delegate :dom_id, to: :helpers

  def index
    live_release!

    unless @release.approvals_enabled?
      redirect_to release_path(@release), flash: {error: "Approvals are disabled for this release."}
      return
    end

    set_approval_variables
  end

  def new
  end

  def create
    live_release!
    @approval_item = @release.approval_items.new(approval_item_params.except(:approval_assignees))
    assign_approval_assignees

    if @approval_item.save
      redirect_to release_approval_items_path(@release), notice: t(".success")
    else
      redirect_to release_approval_items_path(@release), flash: {error: @approval_item.errors.full_messages.to_sentence}
    end
  end

  def update
    live_release!
    @approval_item = @release.approval_items.find_by(id: params[:id])

    unless @approval_item
      approval_item_not_found
      return
    end

    @approval_item = ApprovalsPresenter.new(@approval_item, view_context)

    if @approval_item.update_status(params[:status], current_user)
      set_approval_variables
      render turbo_stream: refresh_items_stream
    else
      flash.now[:error] = I18n.t("approval_items.update.failure")
      render turbo_stream: stream_flash
    end
  end

  def destroy
    live_release!
    @approval_item = @release.approval_items.find_by(id: params[:id])

    unless @approval_item
      approval_item_not_found
      return
    end

    unless @approval_item.not_started?
      set_approval_variables
      @approval_item = ApprovalsPresenter.new(@approval_item, view_context)
      flash.now[:notice] = I18n.t("approval_items.destroy.conflict")
      render turbo_stream: refresh_items_stream
      return
    end

    if @approval_item.destroy
      set_approval_variables
      render turbo_stream: refresh_items_stream
    else
      flash.now[:error] = I18n.t("approval_items.destroy.failure")
      render turbo_stream: stream_flash
    end
  end

  private

  def approval_item_params
    params
      .require(:approval_item).permit(:content, approval_assignees: [])
      .merge(author: current_user, status: ApprovalItem.statuses[:not_started])
  end

  def assign_approval_assignees
    assignee_ids = approval_item_params[:approval_assignees]
    assignee_ids.each do |assignee|
      @approval_item.approval_assignees.build(assignee_id: assignee) if assignee.present?
    end
  end

  def set_approval_variables
    @approval_items = @release.reload.approval_items.map { |i| ApprovalsPresenter.new(i, view_context) }
    @available_assignees = Current.organization.users
    @release = ReleasePresenter.new(@release)
    @app = @release.app
  end

  def approval_item_not_found
    set_approval_variables
    flash.now[:error] = I18n.t("approval_items.not_found")
    render turbo_stream: refresh_items_stream
  end

  def refresh_items_stream
    locals = {
      release: @release,
      available_assignees: @available_assignees,
      items: @approval_items
    }

    [
      stream_flash,
      turbo_stream.update("list_approval_items", partial: "items", locals:)
    ]
  end
end
