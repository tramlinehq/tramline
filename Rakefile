# Add your own tasks in files placed in libs/tasks ending in .rake,
# for example libs/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "config/application"

Rails.application.load_tasks

class Nope < RuntimeError; end

task destructive: :environment do
  puts "This task is destructive! Are you sure you want to continue? [y/N]"
  input = $stdin.gets.chomp
  raise Nope unless input.downcase == "y"
end
