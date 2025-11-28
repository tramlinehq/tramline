class DemoController < ApplicationController
  def index
    demo_org_slug = ENV.fetch("DEMO_ORG_SLUG", nil)
    if demo_org_slug.present?
      demo_org = Accounts::Organization.friendly.find(demo_org_slug)

      redirect_to root_path and return unless demo_org&.demo?

      session[:active_organization] = demo_org_slug
      redirect_to apps_path
      return
    end
    redirect_to root_path
  end
end
