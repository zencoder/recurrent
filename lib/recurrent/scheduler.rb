module Recurrent
  class Scheduler

    attr_accessor :tasks, :logger, :executing_tasks, :mutex

    def initialize(task_file=nil)
      @tasks = TaskCollection.new
      identifier = "host:#{Socket.gethostname} pid:#{Process.pid}" rescue "pid:#{Process.pid}"
      @logger = Logger.new(identifier)
      @mutex = Mutex.new
      @executing_tasks = 0
      eval(File.read(task_file)) if task_file
    end

    def configure
      Configuration
    end

    def create_rule_from_frequency(frequency)
      logger.info "| Creating an IceCube Rule"
      if yearly?(frequency)
        logger.info "| Creating a yearly rule"
        IceCube::Rule.yearly(frequency / 1.year)
      elsif monthly?(frequency)
        logger.info "| Creating a monthly rule"
        IceCube::Rule.monthly(frequency / 1.month)
      elsif weekly?(frequency)
          logger.info "| Creating a weekly rule"
          IceCube::Rule.weekly(frequency / 1.week)
      elsif daily?(frequency)
          logger.info "| Creating a daily rule"
          IceCube::Rule.daily(frequency / 1.day)
      elsif hourly?(frequency)
        logger.info "| Creating an hourly rule"
        IceCube::Rule.hourly(frequency / 1.hour)
      elsif minutely?(frequency)
          logger.info "| Creating a minutely rule"
          IceCube::Rule.minutely(frequency / 1.minute)
      else
        logger.info "| Creating a secondly rule"
        IceCube::Rule.secondly(frequency)
      end
    end

    def create_schedule(name, frequency, start_time=nil)
      saved_schedule = Configuration.load_task_schedule.call(name) if Configuration.load_task_schedule
      new_schedule = frequency.is_a?(IceCube::Schedule) ? frequency : create_schedule_from_frequency(frequency, start_time)
      if saved_schedule
        use_saved_schedule_if_rules_match(saved_schedule, new_schedule)
      else
        new_schedule
      end
    end

    def create_schedule_from_frequency(frequency, start_time=nil)
      logger.info "| Frequency is an integer: #{frequency}"
      rule = create_rule_from_frequency(frequency)
      logger.info "| IceCube Rule created: #{rule.to_s}"
      frequency_in_seconds = frequency
      start_time ||= derive_start_time_from_frequency(frequency_in_seconds)
      schedule = IceCube::Schedule.new(start_time)
      schedule.add_recurrence_rule rule
      schedule
    end

    def derive_start_time_from_frequency(frequency)
      logger.info "| Deriving start time from frequency"
      current_time = Time.now
      if frequency < 1.minute
        logger.info "| Setting start time to beginning of current minute"
        current_time.change(:sec => 0, :usec => 0)
      elsif frequency < 1.hour
        logger.info "| Setting start time to beginning of current hour"
        current_time.change(:min => 0, :sec => 0, :usec => 0)
      elsif frequency < 1.day
        logger.info "| Setting start time to beginning of current day"
        current_time.beginning_of_day
      elsif frequency < 1.week
        logger.info "| Setting start time to beginning of current week"
        current_time.beginning_of_week
      elsif frequency < 1.month
        logger.info "| Setting start time to beginning of current month"
        current_time.beginning_of_month
      elsif frequency < 1.year
        logger.info "| Setting start time to beginning of current year"
        current_time.beginning_of_year
      end
    end

    def every(frequency, key, options={}, &block)
      logger.info "Adding Task: #{key}"
      task = Task.new(:name => key,
                      :schedule => create_schedule(key, frequency, options[:start_time]),
                      :action => block,
                      :save => options[:save],
                      :logger => logger,
                      :scheduler => self)
      @tasks.add_or_update(task)
      logger.info "| #{key} added to Scheduler"
    end

    def use_saved_schedule_if_rules_match(saved_schedule, new_schedule)
      if new_schedule.has_same_rules? saved_schedule
        logger.info "| Schedule matches a saved schedule, using saved schedule."
        saved_schedule.start_date = saved_schedule.next_occurrence
        saved_schedule
      else
        new_schedule
      end
    end

    def increment_executing_tasks
      mutex.synchronize do
        @executing_tasks += 1
      end
    end

    def decrement_executing_tasks
      mutex.synchronize do
       @executing_tasks -= 1
      end
    end

    def self.define_frequencies(*frequencies)
      frequencies.each do |frequency|
        method_name = frequency == :day ? :daily? : :"#{frequency}ly?"
        define_method(method_name) do |number|
          (number % 1.send(frequency)) == 0
        end
      end
    end
    define_frequencies :year, :month, :week, :day, :hour, :minute, :second

  end
end
