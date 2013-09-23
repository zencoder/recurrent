require 'spec_helper'

module Recurrent
  describe Worker do
    describe "#wait_for_running_tasks_indefinitely" do
      context "A worker with no running tasks" do
        before :each do
          @worker = Worker.new
        end

        it "logs that all tasks are finished and returns true" do
          @worker.logger.should_receive(:info).with("All tasks finished, exiting...")
          @worker.wait_for_running_tasks_indefinitely.should be_true
        end
      end

      context "A worker with running tasks" do
        before :each do
          @worker = Worker.new
          @task = Task.new :name => 'worker_test'
          @task.thread = Thread.new { sleep 0.1 }
          @worker.scheduler.tasks << @task
        end

        it "waits for the task to finish and returns true" do
          @worker.logger.should_receive(:info).with("Waiting for worker_test to finish.")
          @worker.logger.should_receive(:info).with("All tasks finished, exiting...")
          @worker.wait_for_running_tasks_indefinitely.should be_true
        end
      end
    end

    describe "#wait_until" do
      it "waits until a specified time" do
        Timecop.freeze(Time.local(2011, 7, 26, 11, 35, 00))
        waiting_thread = Thread.new { Worker.new.wait_until(Time.local(2011, 7, 26, 11, 40, 00)) }
        waiting_thread.alive?.should be_true
        Timecop.travel(Time.local(2011, 7, 26, 11, 40, 00))
        sleep(0.51)
        waiting_thread.alive?.should be_false
        Timecop.return
      end
    end

    describe "setup" do
      before :each do
        Configuration.setup do
          @setup = true
        end
      end

      it "runs any configured setup when a worker is created" do
        @setup.should == nil
        Worker.new
        @setup.should == true
      end

      after :each do
        Configuration.setup = nil
      end
    end
  end
end
