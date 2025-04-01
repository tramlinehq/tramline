module Seed
  def self.demo_mode?
    ENV["SEED_MODE"] == "demo"
  end
end
