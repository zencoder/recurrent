module Recurrent
  class Scheduler

    attr_accessor :tasks

    def initialize
      @tasks = []
      @identifier = "host:#{Socket.gethostname} pid:#{Process.pid}" rescue "pid:#{Process.pid}"
      #eval(File.read("#{Rails.root}/config/recurrences.rb"))
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

        puts execute_at.to_s(:seconds)
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
      message = "[Recurrent Scheduler: #{@identifier}] - #{message}"
      puts message
      RAILS_DEFAULT_LOGGER.info(message)
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
