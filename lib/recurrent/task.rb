module Recurrent
  class Task
    attr_accessor :name, :schedule, :action

    def initialize(options={})
      @name = options[:name]
      @schedule = options[:schedule]
      @action = options[:action]
      Configuration.save_task_schedule.call(name.to_s, schedule.to_yaml) if Configuration.save_task_schedule
    end

    def next_occurrence
      return @next_occurrence if @next_occurrence && @next_occurrence.future?
      @next_occurrence = schedule.next_occurrence
    end

  end
end
