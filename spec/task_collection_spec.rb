require 'spec_helper'

module Recurrent
  describe TaskCollection do
    before(:all) do
      Configuration.logging = "quiet"
    end

    describe "#add_or_update_task" do
      before(:each) do
        @tasks = TaskCollection.new
      end

      context "when adding a new task" do
        before(:each) do
          @task = Task.new(:name => :new_task)
        end

        it "adds the task to the list of tasks" do
          @tasks.size.should == 0
          @tasks.add_or_update(@task)
          @tasks.size.should == 1
          @tasks.first.should == @task
        end
      end

      context "when updating a task" do
        before(:each) do
          @original_frequency = Scheduler.new.create_schedule(:task, 5.seconds)
          @original_action    = proc { "I am the original task!" }
          @original_task      = Task.new(:name      => :task,
                                         :frequency => @original_frequency,
                                         :action    => @original_action)

          @new_frequency = Scheduler.new.create_schedule(:task, 10.seconds)
          @new_action    = proc { "I am the new task!" }
          @new_task      = Task.new(:name      => :task,
                                    :frequency => @new_frequency,
                                    :action    => @new_action)
          @tasks << @original_task
        end

        context "before updating the task" do
          it "has one task" do
            @tasks.size.should == 1
          end

          it "has the original task's action" do
            @tasks.first.action.call.should == "I am the original task!"
          end

          it "has the original task's frequency" do
            @tasks.first.schedule.should == @original_schedule
          end
        end

        context "after updating the task" do
          before(:each) do
            @tasks.add_or_update(@new_task)
          end

          it "has one task" do
            @tasks.size.should == 1
          end

          it "has the new task's action" do
            @tasks.first.action.call.should == "I am the new task!"
          end

          it "has the new task's frequency" do
            @tasks.first.schedule.should == @new_schedule
          end
        end
      end
    end

    describe "#remove_task" do
      context "A TaskCollection with 3 tasks" do
        before(:each) do
          @tasks     = TaskCollection.new
          @task1     = Task.new(:name => :task1)
          @task2     = Task.new(:name => :task2)
          @task3     = Task.new(:name => :task3)
          @tasks.add_or_update(@task1)
          @tasks.add_or_update(@task2)
          @tasks.add_or_update(@task3)
        end

        it "has 3 tasks" do
          @tasks.size.should == 3
          (@tasks | []).should == [@task1, @task2, @task3]
        end

        context "that removes a task" do
          before(:each) do
            @tasks.remove(:task2)
          end

          it "has 2 tasks" do
            @tasks.size.should == 2
            (@tasks | []).should == [@task1, @task3]
          end
        end
      end
    end

    describe "#scheduled_to_execute_at" do
      context "when there are multiple tasks" do
        it "should return all the tasks whose next_occurrence is at the specified time" do
          task_1_schedule = IceCube::Schedule.new(Time.utc(2012, 1, 10))
          task_1_schedule.add_recurrence_rule(IceCube::Rule.minutely(10))

          task_2_schedule = IceCube::Schedule.new(Time.utc(2012, 1, 10))
          task_2_schedule.add_recurrence_rule(IceCube::Rule.minutely(5))

          task_3_schedule = IceCube::Schedule.new(Time.utc(2012, 1, 10))
          task_3_schedule.add_recurrence_rule(IceCube::Rule.minutely(1))

          current_time = Time.utc(2012, 1, 10, 14, 4)
          Timecop.freeze(current_time)

          task1     = Task.new(:name     => 'task1',
                               :schedule => task_1_schedule)
          task2     = Task.new(:name     => 'task2',
                               :schedule => task_2_schedule)
          task3     = Task.new(:name     => 'task3',
                               :schedule => task_3_schedule)
          tasks = TaskCollection.new
          tasks.add_or_update(task1)
          tasks.add_or_update(task2)
          tasks.add_or_update(task3)

          tasks.scheduled_to_execute_at(Time.utc(2012, 1, 10, 14, 5)).should =~ [task2, task3]
          Timecop.return
        end

        context "when :sort_by_frequency => true is passed as an option" do
          it "should return the sorted by frequency, most frequent first" do
            task_1_schedule = IceCube::Schedule.new(Time.utc(2012, 1, 10))
            task_1_schedule.add_recurrence_rule(IceCube::Rule.minutely(10))

            task_2_schedule = IceCube::Schedule.new(Time.utc(2012, 1, 10))
            task_2_schedule.add_recurrence_rule(IceCube::Rule.minutely(5))

            task_3_schedule = IceCube::Schedule.new(Time.utc(2012, 1, 10))
            task_3_schedule.add_recurrence_rule(IceCube::Rule.minutely(1))

            current_time = Time.utc(2012, 1, 10, 14, 4)
            Timecop.freeze(current_time)

            task1     = Task.new(:name     => 'task1',
                                 :schedule => task_1_schedule)
            task2     = Task.new(:name     => 'task2',
                                 :schedule => task_2_schedule)
            task3     = Task.new(:name     => 'task3',
                                 :schedule => task_3_schedule)
            tasks = TaskCollection.new
            tasks.add_or_update(task1)
            tasks.add_or_update(task2)
            tasks.add_or_update(task3)

            first_task, second_task = *tasks.scheduled_to_execute_at(Time.utc(2012, 1, 10, 14, 5), :sort_by_frequency => true)
            first_task.should == task3
            second_task.should == task2
            Timecop.return
          end
        end
      end
    end
  end
end

