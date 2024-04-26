class V2::CommitListComponent < V2::BaseComponent
  renders_many :commits, ->(c) { V2::CommitComponent.new(c, avatar: @avatar) }

  def initialize(avatar: true)
    @avatar = avatar
  end
end
