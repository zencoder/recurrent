module Recurrent
  class Configuration

    class << self
      attr_accessor :task_file

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
      block_accessor :logger
    
    end
  end
end
