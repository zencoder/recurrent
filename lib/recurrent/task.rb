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

      @thread = Thread.new do
        Thread.current["execution_time"] = execution_time
        begin
          if Configuration.maximum_concurrent_tasks.present?
            limit_execution_to_max_concurrency
          else
            call_action
          end
        rescue TooManyExecutingTasks
          scheduler.decrement_executing_tasks
          sleep(0.1)
          retry
        rescue => e
          logger.warn("#{name} - #{e.message}")
          logger.warn(e.backtrace)
        end
      end
    end

    def limit_execution_to_max_concurrency
      if scheduler.increment_executing_tasks <= Configuration.maximum_concurrent_tasks
        call_action
        scheduler.decrement_executing_tasks
      else
        raise TooManyExecutingTasks
      end
    end

    def call_action
      if Configuration.load_task_return_value && action.arity == 1
        previous_value = Configuration.load_task_return_value.call(name)
        return_value = action.call(previous_value)
      else
        return_value = action.call
      end
      save_results(return_value) if save?
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
