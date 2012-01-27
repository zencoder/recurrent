module Recurrent
  class TaskCollection

    def initialize
      @mutex = Mutex.new
      @tasks = []
    end

    def add_or_update(new_task)
      @mutex.synchronize do
        old_task_index = @tasks.index {|task| task.name == new_task.name }
        if old_task_index
          @tasks[old_task_index].schedule = new_task.schedule
          @tasks[old_task_index].action = new_task.action
        else
          @tasks << new_task
        end
      end
    end

    def next_for_execution_at_time(time)
      @mutex.synchronize do
        tasks_running_at_time = @tasks.select {|task| task.running? && task.thread['execution_time'] == time }
        TaskCollection.sort_by_frequency(tasks_running_at_time).first
      end
    end

    def next_execution_time
      @mutex.synchronize do
        @tasks.map { |task| task.next_occurrence }.sort.first
      end
    end

    def remove(name)
      @mutex.synchronize do
        @tasks.reject! {|task| task.name == name }
      end
    end

    def running
      @mutex.synchronize do
        @tasks.select {|task| task.running? }
      end
    end

    def scheduled_to_execute_at(time, opts={})
      @mutex.synchronize do
        current_tasks = @tasks.select {|task| task.next_occurrence == time }
        if opts[:sort_by_frequency]
          TaskCollection.sort_by_frequency(current_tasks)
        else
          current_tasks
        end
      end
    end

    def self.sort_by_frequency(task_list)
      task_list.sort_by do |task|
        task.schedule.rrules.sort_by do |rule|
          rule.frequency_in_seconds
        end.first.frequency_in_seconds
      end
    end


    def method_missing(id, *args, &block)
      @mutex.synchronize do
        @tasks.send(id, *args, &block)
      end
    end
  end
end
