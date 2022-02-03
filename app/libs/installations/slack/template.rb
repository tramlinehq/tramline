module Installations
  class Slack::Template
    TRIGGER_WORKFLOW = <<-WORKFLOW
      Hi! Your CI workflow was triggered.
    WORKFLOW

    BUILD_READY = <<-BUILD
    BUILD
  end
end