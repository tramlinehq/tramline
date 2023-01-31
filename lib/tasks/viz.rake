namespace :viz do
  desc "Wrapper over stateoscope because it is hard to remember the command name"
  task :states, %i[model] => :environment do |_, args|
    Rake::Task["stateoscope:visualize"].invoke(args[:model].to_s)
  end
end
