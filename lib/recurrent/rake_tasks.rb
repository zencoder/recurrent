namespace :recurrent do
  desc "Run the scheduler."
  task :run_tasks, [:task_file] => :environment do |t, args|
    tasks_file = args[:task_file] || "#{Rails.root}/config/recurrences.rb"
    Recurrent::Worker.new(tasks_file).start
  end
end
