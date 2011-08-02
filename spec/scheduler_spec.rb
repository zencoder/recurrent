require 'spec_helper'

module Recurrent
  describe Scheduler do
    before(:all) do
      Configuration.logging = "quiet"
    end

    describe "#log" do
      before(:each) do
        @scheduler = Scheduler.new
      end

      context "when a logger is configured" do
        it "should send a message to the logger" do
          some_logger = stub('logger')
          some_logger.should_receive(:info).with(@scheduler.log_message("testing logger"))
          Configuration.logger do |message|
            some_logger.info(message)
          end
          @scheduler.log("testing logger")
          Configuration.logger = nil
        end
      end
    end

    describe "#log_message" do
      it "adds the scheduler's identifier to the message" do
        scheduler = Scheduler.new
        scheduler.log_message("testing").should == "[Recurrent - Process:#{scheduler.identifier} - Timestamp:#{Time.now.to_s(:seconds)}] - testing"
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

    describe "schedule creation methods" do
      before(:all) do
        @scheduler = Scheduler.new
      end

      describe "#create_rule_from_frequency" do
        context "when the frequency is in years" do
          it "should create a yearly rule" do
            @scheduler.create_rule_from_frequency(2.years).class.should == IceCube::YearlyRule
          end
        end

        context "when the frequency is in months" do
          it "should create a yearly rule" do
            @scheduler.create_rule_from_frequency(3.months).class.should == IceCube::MonthlyRule
          end
        end

        context "when the frequency is in weeks" do
          it "should create a weekly rule" do
            @scheduler.create_rule_from_frequency(2.weeks).class.should == IceCube::WeeklyRule
          end
        end

        context "when the frequency is in days" do
          it "should create a daily rule" do
            @scheduler.create_rule_from_frequency(3.days).class.should == IceCube::DailyRule
          end
        end

        context "when the frequency is in hours" do
          it "should create an hourly rule" do
            @scheduler.create_rule_from_frequency(6.hours).class.should == IceCube::HourlyRule
          end
        end

        context "when the frequency is in minutes" do
          it "should create a minutely rule" do
            @scheduler.create_rule_from_frequency(10.minutes).class.should == IceCube::MinutelyRule
          end
        end

        context "when the frequency is in seconds" do
          it "should create a secondly rule" do
            @scheduler.create_rule_from_frequency(30.seconds).class.should == IceCube::SecondlyRule
          end
        end
      end

      describe "create_schedule" do
        context "when frequency is an IceCube Rule" do
          subject do
            rule = IceCube::Rule.daily(1)
            @scheduler.create_schedule(:test, rule)
          end
          it "should be a schedule" do
            subject.class.should == IceCube::Schedule
          end
          it "should have the correct rule" do
            subject.rrules.first.is_a? IceCube::DailyRule
          end
        end

        context "when frequency is a number" do
          subject do
            @scheduler.create_schedule(:test, 1.day)
          end
          it "should be a schedule" do
            subject.class.should == IceCube::Schedule
          end
          it "should have the correct rule" do
            subject.rrules.first.is_a? IceCube::DailyRule
          end
        end

        context "when start time is not provided" do
          it "should derive its own start time" do
            @scheduler.should_receive(:derive_start_time)
            @scheduler.create_schedule(:test, 1.day)
          end
        end

        context "when start time is provided" do
          it "should not derive its own start time" do
            @scheduler.should_not_receive(:derive_start_time)
            @scheduler.create_schedule(:test, 1.day, Time.now)
          end
        end
      end

      describe "derive_start_time_from_frequency" do
        context "when the current time is 11:35:12 am on July 26th, 2011" do
          before(:all) do
            Timecop.freeze(Time.local(2011, 7, 26, 11, 35, 12))
          end

          context "and the frequency is less than a minute" do
            it "should be 11:35:00, the beginning of the current minute" do
              start_time = @scheduler.derive_start_time_from_frequency(30.seconds)
              start_time.should == Time.local(2011, 7, 26, 11, 35, 00)
            end
          end

          context "and the frequency is less than an hour" do
            it "should be 11:00:00, the beginning of the current hour" do
              start_time = @scheduler.derive_start_time_from_frequency(15.minutes)
              start_time.should == Time.local(2011, 7, 26, 11, 00, 00)
            end
          end

          context "and the frequency is less than a day" do
            it "should be 00:00:00 on July 26th, 2011, the beginning of the current day" do
              start_time = @scheduler.derive_start_time_from_frequency(3.hours)
              start_time.should == Time.local(2011, 7, 26, 00, 00, 00)
            end
          end

          context "and the frequency is less than a week" do
            it "should be 00:00:00 on July 25th, 2011, the beginning of the current week" do
              start_time = @scheduler.derive_start_time_from_frequency(3.days)
              start_time.should == Time.local(2011, 7, 25, 00, 00, 00)
            end
          end

          context "and the frequency is less than a month" do
            it "should be 00:00:00 on July 1st, 2011, the beginning of the current month" do
              start_time = @scheduler.derive_start_time_from_frequency(10.days)
              start_time.should == Time.local(2011, 7, 01, 00, 00, 00)
            end
          end

          context "and the frequency is less than a year" do
            it "should be 00:00:00 on January 1st, 2011, the beginning of the current year" do
              start_time = @scheduler.derive_start_time_from_frequency(2.months)
              start_time.should == Time.local(2011, 1, 01, 00, 00, 00)
            end
          end

          after(:all) do
            Timecop.return
          end
        end
      end

      describe "derive_start_time_from_saved_schedule" do
        before(:all) do
          @scheduler = Scheduler.new
          Configuration.load_task_schedule do |name|
            current_time = Time.new
            current_time.change(:sec => 0, :usec => 0)
            @scheduler.create_schedule(:test, 10.seconds, current_time).to_yaml if name == 'test'
          end
        end

        describe "a schedule being created with a saved schedule with the same name and frequency" do
          it "derives its start time from the saved schedule" do
            @scheduler.should_not_receive(:derive_start_time_from_frequency)
            @scheduler.create_schedule(:test, 10.seconds)
          end

          describe "the created schedule's start time" do
            it "should be the next occurrence of the saved schedule" do
              saved_schedule = IceCube::Schedule.from_yaml(Configuration.load_task_schedule.call('test'))
              created_schedule = @scheduler.create_schedule(:test, 10.seconds)
              created_schedule.start_date.to_s(:seconds).should == saved_schedule.next_occurrence.to_s(:seconds)
            end
          end

        end

        describe "a schedule being created with a saved schedule with the same name and different frequency" do
          it "derives its start time from the frequency" do
            @scheduler.should_receive(:derive_start_time_from_frequency)
            @scheduler.create_schedule(:test, 15.seconds)
          end
        end

        describe "a schedule being created without a saved schedule" do
          it "derives its start time from the frequency" do
            @scheduler.should_receive(:derive_start_time_from_frequency)
            @scheduler.create_schedule(:new_test, 10.seconds)
          end
        end


        after(:all) do
          Configuration.load_task_schedule = nil;
        end
      end
    end

  end
end
