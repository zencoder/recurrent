module Recurrent
  class TooManyExecutingTasks < StandardError; end

  class Task
    attr_accessor :action, :name, :logger, :save, :schedule, :thread, :scheduler

    def initialize(options={})
      @name = options[:name]
      @schedule = options[:schedule]
      @action = options[:action]
      @save = options[:save]
      @logger = options[:logger]
      @scheduler = options[:scheduler]
      Configuration.save_task_schedule.call(name, schedule) if Configuration.save_task_schedule
    end

    def execute(execution_time)
      return handle_still_running(execution_time) if running?
      return if Configuration.maximum_concurrent_tasks.present? && (scheduler.executing_tasks >= Configuration.maximum_concurrent_tasks)
      @thread = Thread.new do
        Thread.current["execution_time"] = execution_time
        scheduler && scheduler.increment_executing_tasks
        begin
          call_action
        rescue => e
          logger.warn("#{name} - #{e.message}")
          logger.warn(e.backtrace)
        ensure
          scheduler && scheduler.decrement_executing_tasks
        end
      end
    end

    def call_action
      if Configuration.task_locking
        Configuration.task_locking.call(name) do
          if Configuration.load_task_return_value && action.arity == 1
            previous_value = Configuration.load_task_return_value.call(name)

            return_value = action.call(previous_value)
          else
            return_value = action.call
          end
          save_results(return_value) if save?
        end
      else
        if Configuration.load_task_return_value && action.arity == 1
          previous_value = Configuration.load_task_return_value.call(name)

          return_value = action.call(previous_value)
        else
          return_value = action.call
        end
        save_results(return_value) if save?
      end
    end

    def handle_still_running(current_time)
      logger.info "#{name}: Execution from #{thread['execution_time'].to_s(:seconds)} still running, aborting this execution."
      if Configuration.handle_slow_task
        Configuration.handle_slow_task.call(name, current_time, thread['execution_time'])
      end
    end

    def next_occurrence
      occurrence = schedule.next_occurrence
      schedule.start_date = occurrence
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
