class Authentication::SessionsController < Devise::SessionsController
  after_action :prepare_intercom_shutdown, only: [:destroy]

  def destroy
    super
  end

  protected

  def prepare_intercom_shutdown
    IntercomRails::ShutdownHelper.prepare_intercom_shutdown(session)
  end
end
