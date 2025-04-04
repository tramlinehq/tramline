module Seed
  def self.demo_mode?
    ENV["SEED_MODE"] == "demo"
  end

  def self.not_demo_mode?
    ENV["SEED_MODE"] != "demo"
  end
end

# TODO: remove all the lint issues...gemfile go back to what's on main
