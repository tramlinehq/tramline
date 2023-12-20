module Notifiers
  module Slack
    class Renderers::StepFailed < Renderers::Base
      TEMPLATE_FILE = "step_failed.json.erb".freeze

      def manual_submission_required_text
        "- Due to a previous rejection, new changes cannot be submitted to the store from Tramline. Please submit the current build (#{@build_number}) for review manually from the Google Play Console by creating a release in a public track (eg. Closed testing, Open testing). Once that is done, you can sync the store status with Tramline and move forward with the release train."
      end
    end
  end
end
