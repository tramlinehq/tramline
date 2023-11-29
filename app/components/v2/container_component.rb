# frozen_string_literal: true

class V2::ContainerComponent < ViewComponent::Base
  renders_one :body
  renders_many :actions
  renders_many :sub_actions

  def initialize(title:, subtitle: nil)
    @title = title
    @subtitle = subtitle
  end

  attr_reader :title, :subtitle
end
