class ReleaseConfig::Platform < Struct.new(:conf)
  def value
    conf.with_indifferent_access
  end

  def internal_release
    ReleaseStep.new(value[:internal_release]) if internal_release?
  end

  def internal_release?
    value[:internal_release].present?
  end

  def only_beta_release?
    !internal_release?
  end

  def beta_submissions?
    beta_release.submissions?
  end

  def beta_release
    ReleaseStep.new(value[:beta_release])
  end

  def production_release
    ReleaseStep.new(value[:production_release]) if production_release?
  end

  def production_release?
    value[:production_release].present?
  end

  def workflows
    Workflows.new(value[:workflows])
  end

  class ReleaseStep < Struct.new(:conf)
    def submissions?
      submissions.present?
    end

    def auto_promote?
      value[:auto_promote]
    end

    def submissions
      Submissions.new(value[:submissions])
    end

    def value
      conf.with_indifferent_access
    end
  end

  class Submissions < Struct.new(:conf)
    def present?
      value.present? && value.first.present?
    end

    def blank? = !present?

    def last
      Submission.new(value.last, value) if present?
    end

    def first
      Submission.new(value.first, value) if present?
    end

    def fetch_by_number(num)
      found = value.find { |d| d[:number] == num }
      found ? Submission.new(found, value) : nil
    end

    def value = conf
  end

  class Submission < Struct.new(:current, :all)
    def next
      return if all.blank?
      next_submission = all.find { |d| d[:number] > number }
      next_submission ? Submission.new(next_submission, all) : nil
    end

    def number = value[:number]

    def auto_promote? = value[:auto_promote]

    def submission_type
      value[:submission_type].constantize
    end

    def rollout_config
      config = value[:rollout_config].presence || {enabled: false, stages: []}

      if config.is_a?(Array)
        config
      elsif config.is_a?(Hash)
        OpenStruct.new(config)
      else
        raise ArgumentError, "Invalid rollout config"
      end
    end

    def submission_config
      OpenStruct.new(value[:submission_config])
    end

    def to_h
      {
        number:,
        auto_promote: auto_promote?,
        submission_type:,
        rollout_config: rollout_config.to_h,
        submission_config: submission_config.to_h
      }
    end

    def hash
      [number, submission_type].hash
    end

    def ==(other)
      hash == other.hash
    end

    def value
      current.with_indifferent_access
    end
  end

  class Workflows < Struct.new(:conf)
    def internal_workflow
      Workflow.new(value[:internal], :internal) if value[:internal].present?
    end

    def release_candidate_workflow
      Workflow.new(value[:release_candidate], :release_candidate)
    end

    def pick_internal_workflow
      internal_workflow || release_candidate_workflow
    end

    def value
      conf.with_indifferent_access
    end
  end

  class Workflow < Struct.new(:conf, :kind)
    def name
      value[:name]
    end

    def id
      value[:id]
    end

    def artifact_name_pattern
      value[:artifact_name]
    end

    def value
      conf.with_indifferent_access
    end
  end
end
