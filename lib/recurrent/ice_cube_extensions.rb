module IceCube
  class Rule
    def frequency_in_seconds
      rule_type = self.class
      if rule_type == IceCube::YearlyRule
        @interval.years
      elsif rule_type == IceCube::MonthlyRule
        @interval.months
      elsif rule_type == IceCube::WeeklyRule
        @interval.weeks
      elsif rule_type == IceCube::DailyRule
        @interval.days
      elsif rule_type == IceCube::HourlyRule
        @interval.hours
      elsif rule_type == IceCube::MinutelyRule
        @interval.minutes
      elsif rule_type == IceCube::SecondlyRule
        @interval.seconds
      end
    end
  end
end