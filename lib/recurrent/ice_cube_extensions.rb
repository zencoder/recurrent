module IceCube
  class Rule

    def ==(another_rule)
      ['@interval', '@validation_types', '@validations'].all? do |variable|
        self.instance_variable_get(variable) == another_rule.instance_variable_get(variable)
      end && self.class.name == another_rule.class.name
    end

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

  class Schedule
    attr_writer :start_time

    def has_same_rules?(other_schedule)
      #self.rrules == other_schedule.rrules //Code used when ice_cube 0.6.8
      new_schedule = self.rrules.first.instance_variable_get("@validations").reject {|k,v| k == :interval}
      saved_schedule = other_schedule.rrules.first.instance_variable_get("@validations").reject {|k,v| k == :interval}
      new_schedule == saved_schedule
    end
  end
end
