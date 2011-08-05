module Recurrent
  class Task
    attr_accessor :action, :name, :logger, :save, :schedule, :thread

    def initialize(options={})
      @name = options[:name]
      @schedule = options[:schedule]
      @action = options[:action]
      @save = options[:save]
      @logger = options[:logger]
      Configuration.save_task_schedule.call(name, schedule) if Configuration.save_task_schedule
    end

    def execute(execution_time)
      return handle_still_running(execution_time) if running?
      @thread = Thread.new do
        Thread.current["execution_time"] = execution_time
        return_value = action.call
        save_results(return_value) if save?
      end
    end

    def execute_action_with_locking
      result = Configuration.task_locking.call(:name => name, :action => action)
      if result.task_ran?
        logger.info "#{name}: Lock established, task completed."
        return_value = result.task_return_value
        save_results(return_value) if save?
      else
        logger.info "#{name}: Unable to establish a lock, task did not run."
      end
    end

    def handle_still_running(current_time)
      logger.info "#{name}: Execution from #{thread['execution_time'].to_s(:seconds)} still running, aborting this execution."
      if Configuration.handle_slow_task
        Configuration.handle_slow_task.call(name, current_time)
      end
    end

    def next_occurrence
      return @next_occurrence if @next_occurrence && @next_occurrence.future?
      @next_occurrence = schedule.next_occurrence
    end

    def save?
      !!save
    end

    def save_results(return_value)
      logger.info "#{name}: Wants to save its return value."
      if Configuration.save_task_return_value
        Configuration.save_task_return_value.call(:name => name,
                                                  :return_value => return_value,
                                                  :executed_at => thread['execution_time'],
                                                  :executed_by => logger.identifier)
        logger.info "#{name}: Return value saved."
      else
        logger.info "#{name}: No method to save return values is configured."
      end
    end

    def running?
      thread.try(:alive?)
    end

  end
end
