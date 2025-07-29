class OutgoingWebhooksController < SignedInApplicationController
  before_action :set_app

  def portal
    train = @app.trains.friendly.find(params[:train_id])
    link = train.webhook_integration&.unique_portal_link

    if link
      redirect_to link, allow_other_host: true
    else
      redirect_back fallback_location: root_path,
        flash: {error: "Could not access the Webhooks portal at this moment."}
    end
  end
end
