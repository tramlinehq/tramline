class OutgoingWebhooksController < SignedInApplicationController
  def portal
    set_app
    train = @app.trains.friendly.find(params[:train_id])
    link = train.webhook_integration&.unique_portal_link

    if link
      redirect_to link, allow_other_host: true
    else
      redirect_back fallback_location: root_path,
        flash: {error: "Could not access the Webhooks portal at this moment."}
    end
  end

  def index
    @release =
      Release
        .joins(:outgoing_webhook_events, [train: :app])
        .where(apps: {organization: current_organization})
        .friendly.find(params[:release_id])
    webhook_integration = @release.train.webhook_integration

    if webhook_integration&.available?
      @dom_id = helpers.dom_id(webhook_integration)
      @events_component = OutgoingWebhookEventsComponent.new(
        @release.outgoing_webhook_events.recent,
        view_all_link: webhook_integration.unique_portal_link
      )
    else
      @events_component = OutgoingWebhookEventsComponent.new([])
    end
  end
end
