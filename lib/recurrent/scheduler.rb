module Recurrent
  class Scheduler

    attr_accessor :tasks
    attr_reader :identifier

    def initialize(task_file=nil)
      @tasks = []
      @identifier = "host:#{Socket.gethostname} pid:#{Process.pid}" rescue "pid:#{Process.pid}"
      eval(File.read(task_file)) if task_file
    end

    def configure
      Configuration
    end

    def execute
      log "Starting Recurrent"

      trap('TERM') { log 'Exiting...'; $exit = true }
      trap('INT')  { log 'Exiting...'; $exit = true }
      trap('QUIT') { log 'Exiting...'; $exit = true }

      loop do
        execute_at = next_task_time
        tasks_to_execute = tasks_at_time(execute_at)

        until execute_at.past?
          sleep(0.5) unless $exit
        end

        break if $exit

        tasks_to_execute.each do |task|
          Thread.new do
            task.action.call
          end
        end

        break if $exit
      end
    end

    def every(frequency, key, options={}, &block)
      @tasks << Task.new(:name => key,
                         :schedule => frequency,
                         :action => block)
    end

    def log(message)
      message = log_message(message)
      puts message
      Configuration.logger.call(message) if Configuration.logger
    end

    def log_message(message)
      "[Recurrent Scheduler: #{@identifier}] - #{message}"
    end

    def next_task_time
      @tasks.map { |task| task.next_occurrence }.sort.first
    end

    def tasks_at_time(time)
      tasks.select do |task|
        task.next_occurrence == time
      end
    end
  end
end
