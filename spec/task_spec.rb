require 'spec_helper'

module Recurrent
  describe Task do

    describe "#next_occurrence" do
      context "a task that occurs ever 10 seconds and has just occurred" do
        subject do
          current_time = Time.new
          current_time.change(:sec => 0, :usec => 0)
          Timecop.freeze(current_time)
          Task.new(:name => :test, :schedule => Scheduler.new.create_schedule(:test, 10.seconds, current_time))
        end

        it "should occur 10 seconds from now" do
          subject.next_occurrence.should == 10.seconds.from_now
        end

        it "should cache its next occurrence while it's still valid" do
          subject.schedule.should_receive(:next_occurrence).and_return(10.seconds.from_now)
          subject.next_occurrence
          subject.schedule.should_not_receive(:next_occurrence)
          subject.next_occurrence
        end

        after(:each) do
          Timecop.return
        end

      end
    end

  end
end
