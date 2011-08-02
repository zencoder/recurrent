module Recurrent
  class Scheduler

    attr_accessor :tasks
    attr_reader :identifier

    def initialize(task_file=nil)
      @tasks = []
      @identifier = "host:#{Socket.gethostname} pid:#{Process.pid}" rescue "pid:#{Process.pid}"
      eval(File.read(task_file)) if task_file
    end

    def configure
      Configuration
    end

    def create_rule_from_frequency(frequency)
      log "| Creating an IceCube Rule"
      case frequency.inspect
      when /year/
        log "| Creating a yearly rule"
        IceCube::Rule.yearly(frequency / 1.year)
      when /month/
        log "| Creating a monthly rule"
        IceCube::Rule.monthly(frequency / 1.month)
      when /day/
        if ((frequency / 1.week).is_a? Integer) && ((frequency / 1.week) != 0)
          log "| Creating a weekly rule"
          IceCube::Rule.weekly(frequency / 1.week)
        else
          log "| Creating a daily rule"
          IceCube::Rule.daily(frequency / 1.day)
        end
      else
        if ((frequency / 1.hour).is_a? Integer) && ((frequency / 1.hour) != 0)
          log "| Creating an hourly rule"
          IceCube::Rule.hourly(frequency / 1.hour)
        elsif ((frequency / 1.minute).is_a? Integer) && ((frequency / 1.minute) != 0)
            log "| Creating a minutely rule"
            IceCube::Rule.minutely(frequency / 1.minute)
        else
          log "| Creating a secondly rule"
          IceCube::Rule.secondly(frequency)
        end
      end
    end

    def create_schedule(name, frequency, start_time=nil)
      log "| Creating schedule"
      if frequency.is_a? IceCube::Rule
        log "| Frequency is an IceCube Rule: #{frequency.to_s}"
        rule = frequency
        frequency_in_seconds = rule.frequency_in_seconds
      else
        log "| Frequency is an integer: #{frequency}"
        rule = create_rule_from_frequency(frequency)
        log "| IceCube Rule created: #{rule.to_s}"
        frequency_in_seconds = frequency
      end
      start_time ||= derive_start_time(name, frequency_in_seconds)
      schedule = IceCube::Schedule.new(start_time)
      schedule.add_recurrence_rule rule
      log "| schedule created"
      schedule
    end

    def derive_start_time(name, frequency)
      log "| No start time provided, deriving one."
      if Configuration.load_task_schedule
        log "| Attempting to derive from saved schedule"
        derive_start_time_from_saved_schedule(name, frequency)
      else
        derive_start_time_from_frequency(frequency)
      end
    end

    def derive_start_time_from_saved_schedule(name, frequency)
      saved_schedule = Configuration.load_task_schedule.call(name)
      if saved_schedule
        log "| Saved schedule found"
        if saved_schedule.rrules.first.frequency_in_seconds == frequency
          log "| Saved schedule frequency matches, setting start time to saved schedules next occurrence: #{saved_schedule.next_occurrence.to_s(:seconds)}"
          saved_schedule.next_occurrence
        else
          log "| Schedule frequency does not match saved schedule frequency"
          derive_start_time_from_frequency(frequency)
        end
      else
        derive_start_time_from_frequency(frequency)
      end
    end

    def derive_start_time_from_frequency(frequency)
      log "| Deriving start time from frequency"
      current_time = Time.now
      if frequency < 1.minute
        log "| Setting start time to beginning of current minute"
        current_time.change(:sec => 0, :usec => 0)
      elsif frequency < 1.hour
        log "| Setting start time to beginning of current hour"
        current_time.change(:min => 0, :sec => 0, :usec => 0)
      elsif frequency < 1.day
        log "| Setting start time to beginning of current day"
        current_time.beginning_of_day
      elsif frequency < 1.week
        log "| Setting start time to beginning of current week"
        current_time.beginning_of_week
      elsif frequency < 1.month
        log "| Setting start time to beginning of current month"
        current_time.beginning_of_month
      elsif frequency < 1.year
        log "| Setting start time to beginning of current year"
        current_time.beginning_of_year
      end
    end

    def handle_task_still_running(task, current_time)
      if Configuration.handle_slow_task
        Configuration.handle_slow_task.call(task.name, current_time, task.current_execution_timestamp)
      end
      log "#{task.name}: Execution from #{task.current_execution_timestamp.to_s(:seconds)} still running, aborting this execution."
    end

    def every(frequency, key, options={}, &block)
      log "Adding Task: #{key}"
      @tasks << Task.new(:name => key,
                         :schedule => create_schedule(key, frequency, options[:start_time]),
                         :action => block,
                         :save => options[:save])
      log "| #{key} added to Scheduler"
    end

    def execute
      log "Starting Recurrent"

      trap('TERM') { log 'Waiting for running tasks and exiting...'; $exit = true }
      trap('INT')  { log 'Waiting for running tasks and exiting...'; $exit = true }
      trap('QUIT') { log 'Waiting for running tasks and exiting...'; $exit = true }

      loop do
        execution_time = next_task_time
        tasks_to_execute = tasks_at_time(execution_time)

        wait_for_running_tasks && break if $exit

        wait_until(execution_time)

        wait_for_running_tasks && break if $exit

        tasks_to_execute.each do |task|
          log "#{task.name}: Executing at #{execution_time.to_s(:seconds)}"
          if task.running?
            handle_task_still_running(task, execution_time)
          else
            task.current_execution_timestamp = execution_time
            execute_task(task)
          end
        end

        wait_for_running_tasks && break if $exit
      end
    end

    def execute_task(task)
      task.thread = Thread.new do
        if Configuration.task_locking
          execute_task_with_locking(task)
        else
          return_value = task.action.call
          save_task_results(task, return_value) if task.save?
        end
        task.current_execution_timestamp = nil
        task.thread = nil
      end
    end

    def execute_task_with_locking(task)
      result = Configuration.task_locking.call(:name => task.name, :action => task.action)
      if result.task_ran?
        log "#{task.name}: Lock established, task completed."
        return_value = result.task_return_value
        save_task_results(task, return_value) if task.save?
      else
        log "#{task.name}: Unable to establish a lock, task did not run."
      end
    end

    def log(message)
      message = log_message(message)
      puts message unless Configuration.logging == "quiet"
      Configuration.logger.call(message) if Configuration.logger
    end

    def log_message(message)
      "[Recurrent - Process:#{@identifier} - Timestamp:#{Time.now.to_s(:seconds)}] - #{message}"
    end

    def next_task_time
      @tasks.map { |task| task.next_occurrence }.sort.first
    end

    def save_task_results(task, return_value)
      log "#{task.name}: Wants to save its return value."
      if Configuration.save_task_return_value
        Configuration.save_task_return_value.call(:name => task.name,
                                                  :return_value => return_value,
                                                  :executed_at => task.current_execution_timestamp,
                                                  :executed_by => @identifier)
        log "#{task.name}: Return value saved."
      else
        log "#{task.name}: No method to save return values is configured."
      end
    end

    def tasks_at_time(time)
      tasks.select do |task|
        task.next_occurrence == time
      end
    end

    def wait_for_running_tasks
      if task = running_tasks.first
        log "Waiting for #{task.name} to finish."
        task.thread.try(:join)
        wait_for_running_tasks
      else
        log "All tasks finished, exiting..."
        true
      end
    end

    def running_tasks
      tasks.select do |task|
        task.running?
      end
    end

    def wait_until(time)
      until time.past?
        sleep(0.5) unless $exit
      end
    end

  end
end
