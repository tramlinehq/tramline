class ApplicationController < ActionController::Base
  using RefinedString
  include ExceptionHandler if Rails.env.production? || ENV["GRACEFUL_ERROR_PAGES"].to_boolean

  def raise_not_found
    raise ActionController::RoutingError, "Unknown url: #{params[:unmatched_route]}"
  end

  unless Rails.env.production?
    around_action :n_plus_one_detection

    def n_plus_one_detection
      Prosopite.scan
      yield
    ensure
      Prosopite.finish
    end
  end
end
