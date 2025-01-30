# frozen_string_literal: true

class SearchBarComponent < ViewComponent::Base
  def initialize(path:, placeholder:, value:, turbo_frame: nil, default_params: {})
    @path = path
    @placeholder = placeholder
    @initial_value = value
    @turbo_frame = turbo_frame
    @default_params = default_params
  end

  attr_reader :path, :placeholder, :initial_value, :turbo_frame, :default_params
end
