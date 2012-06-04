require 'spec_helper'

module Recurrent
  describe Task do
    before(:all) do
      Configuration.logging = "quiet"
    end

    describe "#execute" do
      before :each do
        @executing_task_time = 5.minutes.ago
        @current_time = Time.now
        @task = Task.new :name => 'execute test', :logger => Logger.new('some identifier'), :action => proc { 'blah' }
      end

      context "The task is still running a previous execution" do
        before :each do
          @task.thread = Thread.new { Thread.current["execution_time"] = @executing_task_time; sleep(1) }
        end

        it "calls #handle_still_running and does not execute the task" do
          @task.should_receive(:handle_still_running).with(@current_time)
          Thread.should_not_receive(:new)
          @task.execute(@current_time)
        end
      end

      it "doesn't call #handle_still_running" do
        @task.should_not_receive(:handle_still_running)
        @task.execute(@current_time)
      end

      it "creates a thread" do
        Thread.should_receive(:new)
        @task.execute(@current_time)
      end

      it "sets its execution_time" do
        @task.execute(@current_time)
        @task.thread['execution_time'].should == @current_time
      end

      context "load_task_return_value is configured" do
        before :each do
          Configuration.load_task_return_value do
            "testing"
          end
        end

        context "the action doesn't take an argument" do
          it "calls the action with a nil argument" do
            @task.action.should_receive(:call)
            @task.execute(@current_time)
          end
        end

        context "the action takes an argument" do
          before :each do
            @task.action = proc { |previous_value| "derp" }
          end

          it "loads the task return value and calls the action with it as an argument" do
            @task.action.should_receive(:call).with("testing")
            @task.execute(@current_time)
          end

          after :each do
            @task.action = proc { "derp" }
          end
        end
        after :each do
          Configuration.load_task_return_value = nil
        end
      end
    end

    describe "#next_occurrence" do
      context "a task that occurs ever 10 seconds and has just occurred" do
        before :each do
          @current_time = Time.new
          @current_time.change(:sec => 0, :usec => 0)
          Timecop.freeze(@current_time)
          @task = Task.new(:name => :test, :schedule => Scheduler.new.create_schedule(:test, 10.seconds, @current_time))
        end

        it "should occur 10 seconds from now" do
          @task.next_occurrence.should == 10.seconds.from_now
        end

        it "update the start time of the task to the time of this occurrence because IceCube::Schedule#next_occurrence gets progressively slower the farther back the start time is" do
          @task.schedule.start_date.should == @current_time
          @task.next_occurrence.should == 10.seconds.from_now
          @task.schedule.start_date.should == 10.seconds.from_now
        end

        after(:each) do
          Timecop.return
        end

      end
    end

    describe "#handle_still_running" do
      before(:all) do
        @executing_task_time = 5.minutes.ago
        @current_time = Time.now
        @task = Task.new :name => 'handle_still_running_test', :logger => Logger.new('some identifier')
        @task.thread = Thread.new { Thread.current["execution_time"] = @executing_task_time }
      end

      context "When no method for handling a still running task is configured" do
        it "just logs that the task is still running" do
          @task.logger.should_receive(:info).with("handle_still_running_test: Execution from #{@executing_task_time.to_s(:seconds)} still running, aborting this execution.")
          @task.handle_still_running(@current_time)
        end
      end

      context "When a method for handling a still running task is configured" do
        before(:each) do
          Configuration.handle_slow_task { |options| 'testing is fun' }
        end

        it "logs that the task is still running and calls the method" do
          @task.logger.should_receive(:info).with("handle_still_running_test: Execution from #{@executing_task_time.to_s(:seconds)} still running, aborting this execution.")
          Configuration.handle_slow_task.should_receive(:call).with('handle_still_running_test', @current_time, @executing_task_time)
          @task.handle_still_running(@current_time)
        end

        after(:each) do
          Configuration.handle_slow_task = nil
        end
      end
    end

    describe "#save?" do
      describe "A task initialized with :save => true" do
        it "returns true" do
          Task.new(:save => true).save?.should == true
        end
      end

      describe "A task initialized with :save => false" do
        it "returns false" do
          Task.new(:save => false).save?.should == false
        end
      end

      describe "A task initialized with no :save option" do
        it "returns false" do
          Task.new.save?.should == false
        end
      end
    end

    describe "#save_results" do
      context "When no method for saving results is configured" do
        it "logs that information" do
          t = Task.new :name => 'save_results_test', :logger => Logger.new('some identifier')
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

    describe "Restricting to a maximum number of concurrent tasks" do
      before(:each) do
        scheduler = Scheduler.new
        schedule = IceCube::Schedule.new(Time.now.utc.beginning_of_day)
        schedule.add_recurrence_rule IceCube::Rule.minutely(1)
        @task1 = Task.new(:name => 'task1',
                         :scheduler => scheduler,
                         :schedule => schedule.clone,
                         :action => lambda { sleep(1); $tasks_executed += 1 })
        @task2 = Task.new(:name => 'task2',
                         :scheduler => scheduler,
                         :schedule => schedule.clone,
                         :action => lambda { sleep(1); $tasks_executed += 1 })

        scheduler.tasks.add_or_update(@task1)
        scheduler.tasks.add_or_update(@task2)
        $tasks_executed = 0
      end

      describe "when there is no concurrent task limit set" do
        it "should run all tasks at the same time" do
          current_time = Time.now
          [@task1, @task2].each do |task|
            task.execute(current_time)
          end

          [@task1, @task2].each {|task| task.thread.join }

          $tasks_executed.should == 2
        end
      end

      describe "when there is a maximum concurrency limit set" do
        before(:each) do
          Configuration.maximum_concurrent_tasks = 1
        end

        it "throw away tasks if there are too many tasks running" do
          current_time = Time.now

          [@task1, @task2].each do |task|
            task.execute(current_time)
          end

          [@task1, @task2].each {|task| task.thread.try(:join) }

          $tasks_executed.should == 1
        end

        after(:each) do
          Configuration.maximum_concurrent_tasks = nil
        end
      end
    end

  end
end
