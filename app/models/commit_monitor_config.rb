#todo should be monitored_branch not monitored_branches
#todo set branch from train
class CommitMonitorConfig
  class << self
    def monitored_branches
      @monitored_branches ||= Set.new(['main', 'develop'])
    end

    def add_branch(branch_name)
      monitored_branches.add(branch_name)
    end

    def remove_branch(branch_name)
      monitored_branches.delete(branch_name)
    end

    def monitoring?(branch_name)
      monitored_branches.include?(branch_name)
    end
  end
end 