FactoryBot.define do
  factory :workflow_run do
    commit
    triggering_release factory: %i[pre_prod_release]
    release_platform_run { triggering_release.release_platform_run }
    workflow_config { {id: "123"} }
    status { "created" }
    kind { WorkflowRun::KINDS[:internal] }

    after(:create) do |run|
      create(:build, release_platform_run: run.release_platform_run, workflow_run: run, build_number: nil)
    end

    trait :rc do
      kind { WorkflowRun::KINDS[:release_candidate] }
    end

    trait :internal do
      kind { WorkflowRun::KINDS[:internal] }
    end

    trait :triggering do
      status { "triggering" }
    end

    trait :triggered do
      status { "triggered" }
    end

    trait :started do
      status { "started" }
    end

    trait :failed do
      status { "failed" }
    end

    trait :finished do
      status { "finished" }
    end

    trait :unavailable do
      status { "unavailable" }
    end

    trait :halted do
      status { "halted" }
    end

    trait :cancelling do
      status { "cancelling" }
    end

    trait :cancelled do
      status { "cancelled" }
    end
  end
end
