class ApprovalAssignmentMailer < ApplicationMailer
  def notify(approval_assignee)
    @approval_assignee = approval_assignee
    @approval_item_content = @approval_assignee.approval_item.content
    release = @approval_assignee.approval_item.release
    @release_version = release.release_version
    @release_train = release.train.name
    @release_link = release.live_release_link

    mail(
      to: @approval_assignee.assignee.email,
      subject: I18n.t("approval_assignee_mailer.notify.subject")
    )
  end
end
