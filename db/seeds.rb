# rubocop:disable Rails/Output

seed_mode = ENV["SEED_MODE"] || "dev"
puts "Running seeds script in [#{seed_mode}]: "

if seed_mode == "demo"
  Seed::DemoStarter.call
else
  Seed::DevStarter.call
end

# rubocop:enable Rails/Output
