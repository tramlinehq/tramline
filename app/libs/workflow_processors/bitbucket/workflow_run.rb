class WorkflowProcessors::Bitbucket::WorkflowRun
  def initialize(integration, workflow_run, version_name, build_number)
    @integration = integration
    @workflow_run = workflow_run
    @version_name = version_name
    @build_number = build_number
  end

  # "state"=>{"name"=>"PARSING", "type"=>"pipeline_state_parsing", "stage"=>{"name"=>"PARSING", "type"=>"pipeline_state_parsing_parsing"}},
  # "state"=>{"name"=>"IN_PROGRESS", "type"=>"pipeline_state_in_progress", "stage"=>{"name"=>"RUNNING", "type"=>"pipeline_state_in_progress_running"}},
  def in_progress?
    !pipeline_completed?
  end

  # "state"=>{"name"=>"COMPLETED", "type"=>"pipeline_state_completed", "result"=>{"name"=>"SUCCESSFUL", "type"=>"pipeline_state_completed_successful"}},
  def successful?
    return false unless pipeline_completed?
    status == "SUCCESSFUL" && status_type == "pipeline_state_completed_successful"
  end

  # "state"=>{"name"=>"COMPLETED", "type"=>"pipeline_state_completed", "result"=>{"name"=>"FAILED", "type"=>"pipeline_state_completed_failed"}},
  def failed?
    return false unless pipeline_completed?
    status == "FAILED" && status_type == "pipeline_state_completed_failed"
  end

  # "state"=>
  #   {"name"=>"COMPLETED",
  #    "type"=>"pipeline_state_completed",
  #    "result"=>
  #     {"name"=>"STOPPED",
  #      "type"=>"pipeline_state_completed_stopped",
  #      "terminator"=>
  #       {"display_name"=>"Nivedita Priyadarshini",
  #        "links"=>
  #         {"self"=>{"href"=>"https://api.bitbucket.org/2.0/users/%7Bdb534ec4-33b8-4595-9012-8a86593ac4dd%7D"},
  #          "avatar"=>{"href"=>"https://secure.gravatar.com/avatar/cb35b6f8b777e174b0c46cdbf51a3a64?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FNP-0.png"},
  #          "html"=>{"href"=>"https://bitbucket.org/%7Bdb534ec4-33b8-4595-9012-8a86593ac4dd%7D/"}},
  #        "type"=>"user",
  #        "uuid"=>"{db534ec4-33b8-4595-9012-8a86593ac4dd}",
  #        "account_id"=>"712020:07879f2c-20ca-488b-b5f3-0fd492b8c939",
  #        "nickname"=>"Nivedita Priyadarshini"}}},
  def halted?
    return unless pipeline_completed?
    status == "STOPPED" && status_type == "pipeline_state_completed_stopped"
  end

  # TODO: Implement
  def artifacts_url
    return unless successful?
    "app-prod-debug-#{@version_name}-#{@build_number}.apk"
  end

  def started_at
    workflow_run[:created_on]
  end

  def finished_at
    workflow_run[:completed_on]
  end

  private

  attr_reader :workflow_run

  def pipeline_completed?
    pipeline_status_type == "pipeline_state_completed" && pipeline_status == "COMPLETED"
  end

  def status
    workflow_run[:state][:result][:name]
  end

  def status_type
    workflow_run[:state][:result][:type]
  end

  def pipeline_status
    workflow_run[:state][:name]
  end

  def pipeline_status_type
    workflow_run[:state][:type]
  end
end
