require 'spec_helper'

module Recurrent
  describe Scheduler do
    describe "#log" do
      before(:each) do
        @scheduler = Scheduler.new
      end

      it "should send a message to puts" do
        @scheduler.should_receive(:puts).with(@scheduler.log_message("testing puts"))
        @scheduler.log("testing puts")
      end

      context "when a logger is configured" do
        it "should send a message to the logger" do
          some_logger = stub('logger')
          some_logger.should_receive(:info).with(@scheduler.log_message("testing logger"))
          Configuration.logger do |message|
            some_logger.info(message)
          end
          @scheduler.log("testing logger")
        end
      end
    end

    describe "#log_message" do
      it "adds the scheduler's identifier to the message" do
        scheduler = Scheduler.new
        scheduler.log_message("testing").should == "[Recurrent Scheduler: #{scheduler.identifier}] - testing"
      end
    end

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
