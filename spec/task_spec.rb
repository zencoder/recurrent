require 'spec_helper'

module Recurrent
  describe Task do

    describe "create_rule_from_frequency" do
      context "when the frequency is in years" do
        it "should create a yearly rule" do
          Task.create_rule_from_frequency(2.years).class.should == IceCube::YearlyRule
        end
      end

      context "when the frequency is in months" do
        it "should create a yearly rule" do
          Task.create_rule_from_frequency(3.months).class.should == IceCube::MonthlyRule
        end
      end

      context "when the frequency is in weeks" do
        it "should create a weekly rule" do
          Task.create_rule_from_frequency(2.weeks).class.should == IceCube::WeeklyRule
        end
      end

      context "when the frequency is in days" do
        it "should create a daily rule" do
          Task.create_rule_from_frequency(3.days).class.should == IceCube::DailyRule
        end
      end

      context "when the frequency is in hours" do
        it "should create an hourly rule" do
          Task.create_rule_from_frequency(6.hours).class.should == IceCube::HourlyRule
        end
      end

      context "when the frequency is in minutes" do
        it "should create a minutely rule" do
          Task.create_rule_from_frequency(10.minutes).class.should == IceCube::MinutelyRule
        end
      end

      context "when the frequency is in seconds" do
        it "should create a secondly rule" do
          Task.create_rule_from_frequency(30.seconds).class.should == IceCube::SecondlyRule
        end
      end
    end

    describe "create_schedule_from_frequency" do
      context "when frequency is an IceCube Rule" do
        subject do
          rule = IceCube::Rule.daily(1)
          Task.create_schedule_from_frequency(rule)
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
          Task.create_schedule_from_frequency(1.day)
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
          Task.should_receive(:derive_start_time)
          Task.create_schedule_from_frequency(1.day)
        end
      end

      context "when start time is provided" do
        it "should not derive its own start time" do
          Task.should_not_receive(:derive_start_time)
          Task.create_schedule_from_frequency(1.day, Time.now)
        end
      end
    end

    describe "derive_start_time" do
      context "when the current time is 11:35:12 am on July 26th, 2011" do
        before(:all) do
          Timecop.freeze(Time.local(2011, 7, 26, 11, 35, 12))
        end

        context "and the frequency is less than a minute" do
          it "should be 11:35:00, the beginning of the current minute" do
            start_time = Task.derive_start_time(30.seconds)
            start_time.should == Time.local(2011, 7, 26, 11, 35, 00)
          end
        end

        context "and the frequency is less than an hour" do
          it "should be 11:00:00, the beginning of the current hour" do
            start_time = Task.derive_start_time(15.minutes)
            start_time.should == Time.local(2011, 7, 26, 11, 00, 00)
          end
        end

        context "and the frequency is less than a day" do
          it "should be 00:00:00 on July 26th, 2011, the beginning of the current day" do
            start_time = Task.derive_start_time(3.hours)
            start_time.should == Time.local(2011, 7, 26, 00, 00, 00)
          end
        end

        context "and the frequency is less than a week" do
          it "should be 00:00:00 on July 25th, 2011, the beginning of the current week" do
            start_time = Task.derive_start_time(3.days)
            start_time.should == Time.local(2011, 7, 25, 00, 00, 00)
          end
        end

        context "and the frequency is less than a month" do
          it "should be 00:00:00 on July 1st, 2011, the beginning of the current month" do
            start_time = Task.derive_start_time(10.days)
            start_time.should == Time.local(2011, 7, 01, 00, 00, 00)
          end
        end

        context "and the frequency is less than a year" do
          it "should be 00:00:00 on January 1st, 2011, the beginning of the current year" do
            start_time = Task.derive_start_time(2.months)
            start_time.should == Time.local(2011, 1, 01, 00, 00, 00)
          end
        end

        after(:all) do
          Timecop.return
        end
      end
    end

  end
end
