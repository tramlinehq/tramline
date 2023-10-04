module MetadataAwareness
  def device
    @device ||= DeviceDetector.new(request.user_agent)
  end

  def current_organization
    @current_organization ||=
      if session[:active_organization]
        begin
          Accounts::Organization.friendly.find(session[:active_organization])
        rescue ActiveRecord::RecordNotFound
          current_user&.organizations&.first
        end
      else
        current_user&.organizations&.first
      end
  end
end
