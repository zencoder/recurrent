module Recurrent
  class Configuration

    class << self

      attr_accessor :logging

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
      block_accessor :logger, :save_task_schedule, :load_task_schedule, :save_task_return_value, :task_locking, :handle_slow_task

    end
  end
end
