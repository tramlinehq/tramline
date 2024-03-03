class V2::ContainerComponent < V2::BaseComponent
  renders_one :back_button, V2::BackButtonComponent
  renders_one :empty_state
  renders_one :body
  renders_many :actions
  renders_many :sub_actions
  renders_many :side_actions

  def initialize(title:, subtitle: nil, error_resource: nil)
    @title = title
    @subtitle = subtitle
    @error_resource = error_resource
  end

  attr_reader :title, :subtitle, :error_resource
end
