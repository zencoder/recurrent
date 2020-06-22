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
      @disable_task_locking = options[:disable_task_locking]
      Configuration.save_task_schedule.call(name, schedule) if Configuration.save_task_schedule
    end

    def execute(execution_time)
      return handle_still_running(execution_time) if running?
      @thread = Thread.new do
        Thread.current["execution_time"] = execution_time
        scheduler && scheduler.increment_executing_tasks
        begin
          if Configuration.maximum_concurrent_tasks.present?
            call_action(execution_time) unless (scheduler.executing_tasks > Configuration.maximum_concurrent_tasks)
          else
            call_action(execution_time)
          end
        rescue => e
          logger.warn("#{name} - #{e.message}")
          logger.warn(e.backtrace)
        ensure
          scheduler && scheduler.decrement_executing_tasks
        end
      end
    end

    def call_action(execution_time=nil)
      if Configuration.task_locking && !@disable_task_locking
        logger.info "#{name} - #{execution_time.to_s(:seconds)}: attempting to establish lock"
        lock_established = Configuration.task_locking.call(name) do
          if Configuration.load_task_return_value && action.arity == 1
            previous_value = Configuration.load_task_return_value.call(name)

            return_value = action.call(previous_value)
          else
            return_value = action.call
          end
          save_results(return_value) if save?

          # If a task finishes quickly hold the lock for a few seconds to avoid releasing it before other processes try to pick up the task
          sleep(1) until Time.now - execution_time > 5 if execution_time
        end
        logger.info "#{name} - #{execution_time.to_s(:seconds)}: locked by another process" unless lock_established
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
      schedule.start_time = occurrence
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
