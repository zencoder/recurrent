module Recurrent
  class Task
    attr_accessor :name, :schedule, :action

    def initialize(options={})
      @name = options[:name]
      @schedule = self.class.create_schedule(options[:name], options[:schedule], options[:start_time])
      @action = options[:action]
      Configuration.save_task_schedule.call(name.to_s, schedule.to_yaml) if Configuration.save_task_schedule
    end

    def next_occurrence
      return @next_occurrence if @next_occurrence && @next_occurrence.future?
      @next_occurrence = schedule.next_occurrence
    end

    def self.create_rule_from_frequency(frequency)
      case frequency.inspect
      when /year/
        IceCube::Rule.yearly(frequency / 1.year)
      when /month/
        IceCube::Rule.monthly(frequency / 1.month)
      when /day/
        if ((frequency / 1.week).is_a? Integer) && ((frequency / 1.week) != 0)
          IceCube::Rule.weekly(frequency / 1.week)
        else
          IceCube::Rule.daily(frequency / 1.day)
        end
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

    def self.create_schedule(name, frequency, start_time=nil)
      if frequency.is_a? IceCube::Rule
        rule = frequency
        frequency_in_seconds = rule.frequency_in_seconds
      else
        rule = create_rule_from_frequency(frequency)
        frequency_in_seconds = frequency
      end
      start_time ||= derive_start_time(name, frequency_in_seconds)
      schedule = IceCube::Schedule.new(start_time)
      schedule.add_recurrence_rule rule
      schedule
    end

    def self.derive_start_time(name, frequency)
      if Configuration.load_task_schedule
        derive_start_time_from_saved_schedule(name, frequency)
      else
        derive_start_time_from_frequency(frequency)
      end
    end

    def self.derive_start_time_from_saved_schedule(name, frequency)
      saved_schedule = Configuration.load_task_schedule.call(name)
      if saved_schedule
        saved_schedule = saved_schedule.from_yaml
        if saved_schedule.frequency_in_seconds == frequency
          saved_schedule.next_occurrence
        else
          derive_start_time_from_frequency(frequency)
        end
      else
        derive_start_time_from_frequency(frequency)
      end
    end

    def self.derive_start_time_from_frequency(frequency)
      current_time = Time.now
      if frequency < 1.minute
        current_time.change(:sec => 0, :usec => 0)
      elsif frequency < 1.hour
        current_time.change(:min => 0, :sec => 0, :usec => 0)
      elsif frequency < 1.day
        current_time.beginning_of_day
      elsif frequency < 1.week
        current_time.beginning_of_week
      elsif frequency < 1.month
        current_time.beginning_of_month
      elsif frequency < 1.year
        current_time.beginning_of_year
      end
    end

  end
end