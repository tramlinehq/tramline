# rubocop:disable Rails/Output

seed_mode = ENV["SEED_MODE"] || "dev"
puts "Running seeds script in [#{seed_mode}]: "
size_config = ENV["SEED_SIZE"] || "medium"

if seed_mode == "demo"
  if size_config == "small"
    Seed::DemoStarter.call(:small)
  elsif size_config == "large"
    Seed::DemoStarter.call(:large)
  else
    Seed::DemoStarter.call # medium is the default
  end
else
  Seed::DevStarter.call
end

# rubocop:enable Rails/Output
