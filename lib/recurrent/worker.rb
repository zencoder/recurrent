module Recurrent
  class Worker

    attr_accessor :scheduler, :logger

    def initialize(task_file=nil)
      @scheduler = Scheduler.new(task_file)
      @logger = scheduler.logger
    end

    def execute
      logger.log "Starting Recurrent"

      trap('TERM') { logger.log 'Waiting for running tasks and exiting...'; $exit = true }
      trap('INT')  { logger.log 'Waiting for running tasks and exiting...'; $exit = true }
      trap('QUIT') { logger.log 'Waiting for running tasks and exiting...'; $exit = true }

      loop do
        execution_time = scheduler.next_task_time
        tasks_to_execute = scheduler.tasks_at_time(execution_time)

        wait_for_running_tasks && break if $exit

        wait_until(execution_time)

        wait_for_running_tasks && break if $exit

        tasks_to_execute.each do |task|
          logger.log "#{task.name}: Executing at #{execution_time.to_s(:seconds)}"
          task.execute(execution_time)
        end

        wait_for_running_tasks && break if $exit
      end
      logger.log("Goodbye.")
    end

    def wait_for_running_tasks
      if Configuration.wait_for_running_tasks_on_exit_for
        wait_for_running_tasks_for(Configuration.wait_for_running_tasks_on_exit_for)
      else
        wait_for_running_tasks_indefinitely
      end
    end

    def wait_for_running_tasks_for(seconds)
      while scheduler.running_tasks.any? do
        logger.log "Killing running tasks in #{seconds.inspect}."
        seconds -= 1
        sleep(1)
        if seconds == 0
          scheduler.running_tasks.each do |task|
            logger.log "Killing #{task.name}."
            task.thread = nil unless task.thread.try(:kill).try(:alive?)
          end
        end
      end
      true
    end

    def wait_for_running_tasks_indefinitely
      if task = scheduler.running_tasks.first
        logger.log "Waiting for #{task.name} to finish."
        task.thread.try(:join)
        wait_for_running_tasks_indefinitely
      else
        logger.log "All tasks finished, exiting..."
        true
      end
    end

    def wait_until(time)
      until time.past?
        sleep(0.5) unless $exit
      end
    end

  end
end
