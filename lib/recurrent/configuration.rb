module Recurrent
  class Configuration

    class << self

      attr_accessor :logging, :wait_for_running_tasks_on_exit_for, :maximum_concurrent_tasks, :pool_size, :locker_pool_size

      def self.block_accessor(*fields)
        fields.each do |field|
          attr_writer field
          eval("
          def #{field}
            if block_given?
              @#{field} = Proc.new
            else
              @#{field}
            end
          end
          ")
        end
      end
      block_accessor :logger, :save_task_schedule, :load_task_schedule, :save_task_return_value, :load_task_return_value, :process_locking, :task_locking, :handle_slow_task, :setup

    end
  end
end
