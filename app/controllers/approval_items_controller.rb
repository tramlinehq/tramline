class ApprovalItemsController < SignedInApplicationController
  include Tabbable

  before_action :require_write_access!, except: [:index]
  delegate :dom_id, to: :helpers

  def index
    live_release!
    @app = @release.app
    @available_assignees = Current.organization.users
    @approval_items = @release.approval_items
  end

  def new
  end

  def create
    live_release!
    @approval_item = @release.approval_items.new(approval_item_params.except(:approval_assignees))
    assign_approval_assignees

    if @approval_item.save
      redirect_to release_approval_items_path(@release), notice: "Approval item was successfully created."
    else
      redirect_to release_approval_items_path(@release), flash: {error: item.errors.full_messages.to_sentence}
    end
  end

  def update
    live_release!
    @approval_item = @release.approval_items.find(params[:id])

    if @approval_item.update_status(params[:status], Current.user)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(dom_id(@approval_item, :edit_approvals_select), partial: "item_select", locals: {item: @approval_item}),
            turbo_stream.replace(dom_id(@approval_item, :edit_approvals_content), partial: "item_content", locals: {item: @approval_item})
          ]
        end
      end
    else
      respond_to do |format|
        format.turbo_stream do
          flash.now[:error] = @approval_item.errors.full_messages.to_sentence
          redirect_to release_approval_items_path(@release), status: :see_other
        end
      end
    end
  end

  def approval_item_params
    params.require(:approval_item).permit(:content, approval_assignees: []).merge(author: release_pilot)
  end

  def release_pilot
    @release_pilot ||= @release.release_pilot
  end

  def assign_approval_assignees
    assignee_ids = approval_item_params[:approval_assignees]
    assignee_ids.each do |assignee|
      @approval_item.approval_assignees.build(assignee_id: assignee) if assignee.present?
    end
  end
end
