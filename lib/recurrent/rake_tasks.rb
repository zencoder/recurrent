namespace :recurrent do
  namespace :scheduler do
    desc "Run the scheduler."
    task :execute_tasks => :environment do |tasks_file|
      tasks_file ||= "#{Rails.root}/config/recurrences.rb"
      Recurrent::Scheduler.new(tasks_file).execute
    end
  end
end
