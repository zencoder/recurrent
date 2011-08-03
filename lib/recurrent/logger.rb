module Recurrent
  class Logger

    attr_reader :identifier

    def initialize(identifier)
      @identifier = identifier
    end

    def log_message(message)
      "[Recurrent - Process:#{@identifier} - Timestamp:#{Time.now.to_s(:seconds)}] - #{message}"
    end

    def self.define_log_levels(*log_levels)
      log_levels.each do |log_level|
        define_method(log_level) do |message|
          message = log_message(message)
          puts message unless Configuration.logging == "quiet"
          Configuration.logger.call(message, log_level) if Configuration.logger
        end
      end
    end
    define_log_levels :info, :debug, :warn

  end
end
