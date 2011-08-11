module Recurrent
  class Worker

    attr_accessor :scheduler, :logger

    def initialize(options={})
      Configuration.setup.call if Configuration.setup
      file = options[:file]
      @scheduler = Scheduler.new(file)
      if options[:every]
        every = eval(options[:every]).to_i
        if options[:ruby]
          @scheduler.every(every, options[:name]) do
            eval(options[:ruby])
          end
        elsif options[:system]
          @scheduler.every(every, options[:name]) do
            system(options[:system])
          end
        end
      end
      @logger = scheduler.logger
    end

    def start
      logger.info "Starting Recurrent"

      trap('TERM') { logger.info 'Waiting for running tasks and exiting...'; $exit = true }
      trap('INT')  { logger.info 'Waiting for running tasks and exiting...'; $exit = true }
      trap('QUIT') { logger.info 'Waiting for running tasks and exiting...'; $exit = true }

      if Configuration.process_locking
        execute_with_locking
      else
        execute
      end

      logger.info("Goodbye.")
    end

    def execute
      loop do
        execution_time = scheduler.next_task_time
        tasks_to_execute = scheduler.tasks_at_time(execution_time)

        wait_for_running_tasks && break if $exit

        wait_until(execution_time)

        wait_for_running_tasks && break if $exit

        tasks_to_execute.each do |task|
          logger.info "#{task.name}: Executing at #{execution_time.to_s(:seconds)}"
          task.execute(execution_time)
        end

        wait_for_running_tasks && break if $exit
      end
    end

    def execute_with_locking
      lock_established = nil
      until lock_established
        break if $exit
        lock_established = Configuration.process_locking.call do
          execute
        end
        break if $exit
        logger.info 'Tasks are being monitored by another process. Standing by.'
        sleep(5)
      end
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
        logger.info "Killing running tasks in #{seconds.inspect}."
        seconds -= 1
        sleep(1)
        if seconds == 0
          scheduler.running_tasks.each do |task|
            logger.info "Killing #{task.name}."
            task.thread = nil unless task.thread.try(:kill).try(:alive?)
          end
        end
      end
      true
    end

    def wait_for_running_tasks_indefinitely
      if task = scheduler.running_tasks.first
        logger.info "Waiting for #{task.name} to finish."
        task.thread.try(:join)
        wait_for_running_tasks_indefinitely
      else
        logger.info "All tasks finished, exiting..."
        true
      end
    end

    def wait_until(time)
      until time.past?
        break if $exit
        sleep(0.5)
      end
    end

  end
end
