module Recurrent
  class Logger

    attr_reader :identifier

    def initialize(identifier)
      @identifier = identifier
    end

    def log(message)
      message = log_message(message)
      puts message unless Configuration.logging == "quiet"
      Configuration.logger.call(message) if Configuration.logger
    end

    def log_message(message)
      "[Recurrent - Process:#{@identifier} - Timestamp:#{Time.now.to_s(:seconds)}] - #{message}"
    end

  end
end