class GithubController < ApplicationController
  def callback
    @code = params[:code]
    puts "Got code: #{code}"
  end
end
