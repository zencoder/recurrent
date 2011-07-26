namespace :recurrent do
  namespace :scheduler do
    desc "Run the scheduler."
    task :execute_tasks => :environment do
      Recurrent::Scheduler.new.execute
    end
  end
end
