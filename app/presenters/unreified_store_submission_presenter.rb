class UnreifiedStoreSubmissionPresenter < SimpleDelegator
  def self.build(conf, parent_release, build)
    reified_submissions = parent_release.store_submissions
    release_platform_run = parent_release.release_platform_run
    conf.submissions.value.filter_map do |c|
      submission_conf = ReleaseConfig::Platform::Submission.new(c)
      unless reified_submission?(reified_submissions, submission_conf)
        new(submission_conf, parent_release, release_platform_run, build)
      end
    end
  end

  def self.reified_submission?(reified_submissions, submission_conf)
    reified_submissions.any? do |submission|
      submission.conf == submission_conf
    end
  end

  def initialize(conf, parent_release, release_platform_run, build)
    sequence_number = conf.number
    id = SecureRandom.uuid
    config = conf.to_h
    unreified_submission =
      conf.submission_type.new(id:, parent_release:, release_platform_run:, build:, sequence_number:, config:)
    super(unreified_submission)
  end

  def status
    "Not yet started"
  end
end
