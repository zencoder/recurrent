require 'spec_helper'

module Recurrent
  describe Scheduler do
    describe "#next_task_time" do
      context "when there are multiple tasks" do
        it "should return the soonest time at which a task is scheduled" do
          task1 = stub('task1')
          task1.stub(:next_occurrence).and_return(10.minutes.from_now)
          task2 = stub('task2')
          task2.stub(:next_occurrence).and_return(5.minutes.from_now)
          task3 = stub('task3')
          task3.stub(:next_occurrence).and_return(15.minutes.from_now)
          schedule = Scheduler.new
          schedule.tasks << task1
          schedule.tasks << task2
          schedule.tasks << task3
          schedule.next_task_time.should == task2.next_occurrence
        end
      end
    end

    describe "#tasks_at_time" do
      context "when there are multiple tasks" do
        it "should return all the tasks whose next_occurrence is at the specified time" do
          in_five_minutes = 5.minutes.from_now
          task1 = stub('task1')
          task1.stub(:next_occurrence).and_return(in_five_minutes)
          task2 = stub('task2')
          task2.stub(:next_occurrence).and_return(10.minutes.from_now)
          task3 = stub('task3')
          task3.stub(:next_occurrence).and_return(in_five_minutes)
          schedule = Scheduler.new
          schedule.tasks << task1
          schedule.tasks << task2
          schedule.tasks << task3
          schedule.tasks_at_time(in_five_minutes).should =~ [task1, task3]
        end
      end
    end
  end
end
