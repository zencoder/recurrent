require 'spec_helper'

module Recurrent
  describe Task do
    before(:all) do
      Configuration.logging = "quiet"
    end

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

    describe "#save_results" do
      context "When no method for saving results is configured" do
        it "logs that information" do
          t = Task.new :name => 'save_results_test'
          t.logger.should_receive(:info).with("save_results_test: Wants to save its return value.")
          t.logger.should_receive(:info).with("save_results_test: No method to save return values is configured.")
          t.save_results('some value')
        end
      end

      context "When a method for saving results is configured" do
        before(:each) do
          Configuration.save_task_return_value = lambda { |options| 'testing is fun'}
          @task = Task.new :name => 'save_results_test', :logger => Logger.new('some identifier')
          @current_time = Time.now
          @task.thread = Thread.new { Thread.current["execution_time"] = @current_time }
        end

        it "calls the method and logs that the value was saved" do
          @task.logger.should_receive(:info).with("save_results_test: Wants to save its return value.")
          Configuration.save_task_return_value.should_receive(:call).with(:name => 'save_results_test',
                                                                          :return_value => 'some value',
                                                                          :executed_at => @current_time,
                                                                          :executed_by => 'some identifier')
          @task.logger.should_receive(:info).with("save_results_test: Return value saved.")
          @task.save_results('some value')
        end

        after(:each) do
          Configuration.save_task_return_value = nil
        end
      end

    end

    describe "#running?" do
      describe "A task with a live thread" do
        it "returns true" do
          t = Task.new
          t.thread = Thread.new { sleep 1 }
          t.running?.should be_true
        end
      end

      describe "A task with a dead thread" do
        it "returns false" do
          t = Task.new
          t.thread = Thread.new { sleep 1 }
          t.thread.kill
          t.running?.should be_false
        end
      end

      describe "A task with no thread" do
        it "returns false" do
          t = Task.new
          t.thread = nil
          t.running?.should be_false
        end
      end

    end
  end
end
