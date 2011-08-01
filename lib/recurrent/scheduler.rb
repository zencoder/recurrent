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

    def execute
      log "Starting Recurrent"

      trap('TERM') { log 'Exiting...'; $exit = true }
      trap('INT')  { log 'Exiting...'; $exit = true }
      trap('QUIT') { log 'Exiting...'; $exit = true }

      loop do
        execute_at = next_task_time
        tasks_to_execute = tasks_at_time(execute_at)

        until execute_at.past?
          sleep(0.5) unless $exit
        end

        break if $exit

        tasks_to_execute.each do |task|
          Thread.new do
            log("#{task.name}: Executing at #{execute_at.to_s(:seconds)}")
            if Configuration.task_locking
              result = Configuration.task_locking.call(:name => task.name.to_s, :action => task.action)
              if result[:task_ran?]
                log("#{task.name}: Lock established, task completed.")
                return_value = result[:task_return_value]
              else
                log("#{task.name}: Unable to establish a lock, task did not run.")
                break
              end
            else
              return_value = task.action.call
            end

            if task.save?
              log("#{task.name}: Wants to save its return value.")
              if Configuration.save_task_return_value
                Configuration.save_task_return_value.call(:name => task.name.to_s,
                                                          :return_value => return_value,
                                                          :executed_at => execute_at,
                                                          :executed_by => @identifier)
                log("#{task.name}: Return value saved.")
              else
                log("#{task.name}: No method to save return values is configured.")
              end
            end
          end
        end

        break if $exit
      end
    end

    def every(frequency, key, options={}, &block)
      log("Adding Task: #{key}") unless Configuration.logging == "quiet"
      @tasks << Task.new(:name => key,
                         :schedule => create_schedule(key, frequency, options[:start_time]),
                         :action => block,
                         :save => options[:save])
      log("| #{key} added to Scheduler") unless Configuration.logging == "quiet"
    end

    def log(message)
      message = log_message(message)
      puts message
      Configuration.logger.call(message) if Configuration.logger
    end

    def log_message(message)
      "[Recurrent - Process:#{@identifier} - Timestamp:#{Time.now.to_s(:seconds)}] - #{message}"
    end

    def next_task_time
      @tasks.map { |task| task.next_occurrence }.sort.first
    end

    def tasks_at_time(time)
      tasks.select do |task|
        task.next_occurrence == time
      end
    end

    def create_rule_from_frequency(frequency)
      log("| Creating an IceCube Rule") unless Configuration.logging == "quiet"
      case frequency.inspect
      when /year/
        log("| Creating a yearly rule") unless Configuration.logging == "quiet"
        IceCube::Rule.yearly(frequency / 1.year)
      when /month/
        log("| Creating a monthly rule") unless Configuration.logging == "quiet"
        IceCube::Rule.monthly(frequency / 1.month)
      when /day/
        if ((frequency / 1.week).is_a? Integer) && ((frequency / 1.week) != 0)
          log("| Creating a weekly rule") unless Configuration.logging == "quiet"
          IceCube::Rule.weekly(frequency / 1.week)
        else
          log("| Creating a daily rule") unless Configuration.logging == "quiet"
          IceCube::Rule.daily(frequency / 1.day)
        end
      else
        if ((frequency / 1.hour).is_a? Integer) && ((frequency / 1.hour) != 0)
          log("| Creating an hourly rule") unless Configuration.logging == "quiet"
          IceCube::Rule.hourly(frequency / 1.hour)
        elsif ((frequency / 1.minute).is_a? Integer) && ((frequency / 1.minute) != 0)
            log("| Creating a minutely rule") unless Configuration.logging == "quiet"
            IceCube::Rule.minutely(frequency / 1.minute)
        else
          log("| Creating a secondly rule") unless Configuration.logging == "quiet"
          IceCube::Rule.secondly(frequency)
        end
      end
    end

    def create_schedule(name, frequency, start_time=nil)
      log("| Creating schedule") unless Configuration.logging == "quiet"
      if frequency.is_a? IceCube::Rule
        log("| Frequency is an IceCube Rule: #{frequency.to_s}") unless Configuration.logging == "quiet"
        rule = frequency
        frequency_in_seconds = rule.frequency_in_seconds
      else
        log("| Frequency is an integer: #{frequency}") unless Configuration.logging == "quiet"
        rule = create_rule_from_frequency(frequency)
        log("| IceCube Rule created: #{rule.to_s}") unless Configuration.logging == "quiet"
        frequency_in_seconds = frequency
      end
      start_time ||= derive_start_time(name, frequency_in_seconds)
      schedule = IceCube::Schedule.new(start_time)
      schedule.add_recurrence_rule rule
      log("| schedule created") unless Configuration.logging == "quiet"
      schedule
    end

    def derive_start_time(name, frequency)
      log("| No start time provided, deriving one.") unless Configuration.logging == "quiet"
      if Configuration.load_task_schedule
        log("| Attempting to derive from saved schedule") unless Configuration.logging == "quiet"
        derive_start_time_from_saved_schedule(name, frequency)
      else
        derive_start_time_from_frequency(frequency)
      end
    end

    def derive_start_time_from_saved_schedule(name, frequency)
      saved_schedule = Configuration.load_task_schedule.call(name.to_s)
      if saved_schedule
        log("| Saved schedule found") unless Configuration.logging == "quiet"
        saved_schedule = IceCube::Schedule.from_yaml(saved_schedule)
        if saved_schedule.rrules.first.frequency_in_seconds == frequency
          log("| Saved schedule frequency matches, setting start time to saved schedules next occurrence: #{saved_schedule.next_occurrence.to_s(:seconds)}") unless Configuration.logging == "quiet"
          saved_schedule.next_occurrence
        else
          log("| Schedule frequency does not match saved schedule frequency") unless Configuration.logging == "quiet"
          derive_start_time_from_frequency(frequency)
        end
      else
        derive_start_time_from_frequency(frequency)
      end
    end

    def derive_start_time_from_frequency(frequency)
      log("| Deriving start time from frequency") unless Configuration.logging == "quiet"
      current_time = Time.now
      if frequency < 1.minute
        log("| Setting start time to beginning of current minute") unless Configuration.logging == "quiet"
        current_time.change(:sec => 0, :usec => 0)
      elsif frequency < 1.hour
        log("| Setting start time to beginning of current hour") unless Configuration.logging == "quiet"
        current_time.change(:min => 0, :sec => 0, :usec => 0)
      elsif frequency < 1.day
        log("| Setting start time to beginning of current day") unless Configuration.logging == "quiet"
        current_time.beginning_of_day
      elsif frequency < 1.week
        log("| Setting start time to beginning of current week") unless Configuration.logging == "quiet"
        current_time.beginning_of_week
      elsif frequency < 1.month
        log("| Setting start time to beginning of current month") unless Configuration.logging == "quiet"
        current_time.beginning_of_month
      elsif frequency < 1.year
        log("| Setting start time to beginning of current year") unless Configuration.logging == "quiet"
        current_time.beginning_of_year
      end
    end
  end
end
