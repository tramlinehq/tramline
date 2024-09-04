FactoryBot.define do
  factory :release_health_metric do
    deployment_run

    daily_users { 100 }
    daily_users_with_errors { 10 }
    errors_count { 10 }
    new_errors_count { 1 }
    sessions { 1000 }
    sessions_in_last_day { 100 }
    sessions_with_errors { 10 }
    total_sessions_in_last_day { 5000 }
    fetched_at { Time.current }
  end
end
