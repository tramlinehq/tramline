# frozen_string_literal: true

module Notifiers
  module Slack
    class Renderers::RcFinished < Renderers::Base
      TEMPLATE_FILE = "rc_finished.json.erb"

      delegate :changes_limit, to: Renderers::Changelog
    end
  end
end
