module Recurrent
  class Scheduler

    attr_accessor :tasks, :logger

    def initialize(task_file=nil)
      @tasks = []
      identifier = "host:#{Socket.gethostname} pid:#{Process.pid}" rescue "pid:#{Process.pid}"
      @logger = Logger.new(identifier)
      eval(File.read(task_file)) if task_file
    end

    def configure
      Configuration
    end

    def create_rule_from_frequency(frequency)
      logger.log "| Creating an IceCube Rule"
      case frequency.inspect
      when /year/
        logger.log "| Creating a yearly rule"
        IceCube::Rule.yearly(frequency / 1.year)
      when /month/
        logger.log "| Creating a monthly rule"
        IceCube::Rule.monthly(frequency / 1.month)
      when /day/
        if ((frequency / 1.week).is_a? Integer) && ((frequency / 1.week) != 0)
          logger.log "| Creating a weekly rule"
          IceCube::Rule.weekly(frequency / 1.week)
        else
          logger.log "| Creating a daily rule"
          IceCube::Rule.daily(frequency / 1.day)
        end
      else
        if ((frequency / 1.hour).is_a? Integer) && ((frequency / 1.hour) != 0)
          logger.log "| Creating an hourly rule"
          IceCube::Rule.hourly(frequency / 1.hour)
        elsif ((frequency / 1.minute).is_a? Integer) && ((frequency / 1.minute) != 0)
            logger.log "| Creating a minutely rule"
            IceCube::Rule.minutely(frequency / 1.minute)
        else
          logger.log "| Creating a secondly rule"
          IceCube::Rule.secondly(frequency)
        end
      end
    end

    def create_schedule(name, frequency, start_time=nil)
      logger.log "| Creating schedule"
      if frequency.is_a? IceCube::Rule
        logger.log "| Frequency is an IceCube Rule: #{frequency.to_s}"
        rule = frequency
        frequency_in_seconds = rule.frequency_in_seconds
      else
        logger.log "| Frequency is an integer: #{frequency}"
        rule = create_rule_from_frequency(frequency)
        logger.log "| IceCube Rule created: #{rule.to_s}"
        frequency_in_seconds = frequency
      end
      start_time ||= derive_start_time(name, frequency_in_seconds)
      schedule = IceCube::Schedule.new(start_time)
      schedule.add_recurrence_rule rule
      logger.log "| schedule created"
      schedule
    end

    def derive_start_time(name, frequency)
      logger.log "| No start time provided, deriving one."
      if Configuration.load_task_schedule
        logger.log "| Attempting to derive from saved schedule"
        derive_start_time_from_saved_schedule(name, frequency)
      else
        derive_start_time_from_frequency(frequency)
      end
    end

    def derive_start_time_from_saved_schedule(name, frequency)
      saved_schedule = Configuration.load_task_schedule.call(name)
      if saved_schedule
        logger.log "| Saved schedule found"
        if saved_schedule.rrules.first.frequency_in_seconds == frequency
          logger.log "| Saved schedule frequency matches, setting start time to saved schedules next occurrence: #{saved_schedule.next_occurrence.to_s(:seconds)}"
          saved_schedule.next_occurrence
        else
          logger.log "| Schedule frequency does not match saved schedule frequency"
          derive_start_time_from_frequency(frequency)
        end
      else
        derive_start_time_from_frequency(frequency)
      end
    end

    def derive_start_time_from_frequency(frequency)
      logger.log "| Deriving start time from frequency"
      current_time = Time.now
      if frequency < 1.minute
        logger.log "| Setting start time to beginning of current minute"
        current_time.change(:sec => 0, :usec => 0)
      elsif frequency < 1.hour
        logger.log "| Setting start time to beginning of current hour"
        current_time.change(:min => 0, :sec => 0, :usec => 0)
      elsif frequency < 1.day
        logger.log "| Setting start time to beginning of current day"
        current_time.beginning_of_day
      elsif frequency < 1.week
        logger.log "| Setting start time to beginning of current week"
        current_time.beginning_of_week
      elsif frequency < 1.month
        logger.log "| Setting start time to beginning of current month"
        current_time.beginning_of_month
      elsif frequency < 1.year
        logger.log "| Setting start time to beginning of current year"
        current_time.beginning_of_year
      end
    end

    def every(frequency, key, options={}, &block)
      logger.log "Adding Task: #{key}"
      @tasks << Task.new(:name => key,
                         :schedule => create_schedule(key, frequency, options[:start_time]),
                         :action => block,
                         :save => options[:save],
                         :logger => logger)
      logger.log "| #{key} added to Scheduler"
    end

    def next_task_time
      tasks.map { |task| task.next_occurrence }.sort.first
    end

    def running_tasks
      tasks.select do |task|
        task.running?
      end
    end

    def start_worker
      Worker.new(self, logger).execute
    end

    def tasks_at_time(time)
      tasks.select do |task|
        task.next_occurrence == time
      end
    end

  end
end
