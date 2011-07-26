module Recurrent
  class Scheduler

    attr_accessor :tasks

    def initialize
      @tasks = []
      @identifier = "host:#{Socket.gethostname} pid:#{Process.pid}" rescue "pid:#{Process.pid}"
      eval(File.read("#{Rails.root}/config/recurrences.rb"))
    end

    def create_rule_from_frequency(frequency)
      case frequency.inspect
      when /year/
        IceCube::Rule.yearly(frequency / 1.year)
      when /month/
        IceCube::Rule.monthly(frequency / 1.month)
      when /day/
        IceCube::Rule.daily(frequency / 1.day)
      else
        if ((frequency / 1.hour).is_a? Integer) && ((frequency / 1.hour) != 0)
          IceCube::Rule.hourly(frequency / 1.hour)
        elsif
          ((frequency / 1.minute).is_a? Integer) && ((frequency / 1.minute) != 0)
            IceCube::Rule.minutely(frequency / 1.minute)
        else
          IceCube::Rule.secondly(frequency)
        end
      end
    end

    def create_schedule_from_frequency(frequency)
      schedule = IceCube::Schedule.new(start_time(frequency))
      rule = create_rule_from_frequency(frequency)
      schedule.add_recurrence_rule rule
      schedule
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

        puts execute_at.to_s(:seconds)
        tasks_to_execute.each do |task|
          Thread.new do
            task[:task].call
          end
        end

        break if $exit
      end
    end

    def every(frequency, key, options={}, &block)
      @tasks << { :name => key,
                  :schedule => create_schedule_from_frequency(frequency),
                  :task => block }
    end

    def log(message)
      message = "[Recurrent Scheduler: #{@identifier}] - #{message}"
      puts message
      RAILS_DEFAULT_LOGGER.info(message)
    end

    def next_task_time
      @tasks.sort_by { |task| next_time = task[:schedule].next_occurrence }.first[:schedule].next_occurrence
    end

    def start_time(frequency)
      current_time = Time.now
      if frequency.is_a? IceCube::Rule
        case frequency
        when IceCube::YearlyRule
          current_time.beginning_of_year
        when IceCube::MonthlyRule
          current_time.beginning_of_month
        when IceCube::DailyRule
          current_time.beginning_of_day
        when IceCube::HourlyRule
          current_time.change(:min => 0, :sec => 0, :usec => 0)
        when IceCube::MinutelyRule
          current_time.change(:sec => 0, :usec => 0)
        when IceCube::SecondlyRule
          current_time.change(:usec => 0)
        end
      else
        if frequency < 1.second
          current_time.change(:usec => 0)
        elsif frequency < 1.minute
          current_time.change(:sec => 0, :usec => 0)
        elsif frequency < 1.hour
          current_time.change(:min => 0, :sec => 0, :usec => 0)
        elsif frequency < 1.day
          current_time.beginning_of_day
        elsif frequency < 1.month
          current_time.beginning_of_month
        elsif frequency < 1.year
          current_time.beginning_of_year
        end
      end
    end

    def tasks_at_time(time)
      tasks.select do |task|
        task[:schedule].next_occurrence == time
      end
    end
  end
end
