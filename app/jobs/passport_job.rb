class PassportJob < ApplicationJob
  def perform(stampable_id, stampable_type, params = {})
    stampable = begin
      stampable_type.constantize.find(stampable_id)
    rescue NameError, ActiveRecord::RecordNotFound => e
      elog(e)
    end

    params = params.with_indifferent_access
    Passport.stamp!(
      stampable: stampable,
      reason: params[:reason],
      kind: params[:kind],
      message: params[:message],
      metadata: params[:metadata],
      event_timestamp: params[:event_timestamp],
      automatic: params[:automatic],
      author_id: params[:author_id],
      author_metadata: params[:author_metadata]
    )
  end
end
