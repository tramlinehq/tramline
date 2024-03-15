class V2::CommitListComponent < V2::BaseComponent
  renders_many :commits, V2::CommitComponent
end
