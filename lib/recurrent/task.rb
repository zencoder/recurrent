module Recurrent
  class Task
    attr_accessor :name, :schedule, :action

    def initialize(options={})
      @name = options[:name]
      @schedule = self.class.create_schedule_from_frequency(options[:schedule], options[:start_time])
      @action = options[:action]
    end

    def next_occurrence
      return @next_occurrence if @next_occurrence && (@next_occurrence > Time.now)
      @next_occurrence = schedule.next_occurrence
    end

    def self.create_rule_from_frequency(frequency)
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

    def self.create_schedule_from_frequency(frequency, start_time=nil)
      schedule = IceCube::Schedule.new(start_time || derive_start_time(frequency))
      rule = create_rule_from_frequency(frequency)
      schedule.add_recurrence_rule rule
      schedule
    end

    def self.derive_start_time(frequency)
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

  end
end