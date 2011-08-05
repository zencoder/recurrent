require 'spec_helper'

module Recurrent
  describe Logger do
    before(:each) do
      @logger = Logger.new('logtastic')
      @users_logger = stub('logger')
      Configuration.logger do |message, log_level|
        @users_logger.info(message) if log_level == :info
        @users_logger.debug(message) if log_level == :debug
        @users_logger.warn(message) if log_level == :warn
      end
    end

    after(:all) do
      Configuration.logger = nil
    end

    describe "#info" do
      it "should send a message to the logger with the info logging level" do
        @users_logger.should_receive(:info).with(@logger.log_message("testing logger"))
        @logger.info("testing logger")
      end
    end

    describe "#debug" do
      it "should send a message to the logger with the debug logging level" do
        @users_logger.should_receive(:debug).with(@logger.log_message("testing logger"))
        @logger.debug("testing logger")
      end
    end

    describe "#warn" do
      it "should send a message to the logger with the info logging level" do
        @users_logger.should_receive(:warn).with(@logger.log_message("testing logger"))
        @logger.warn("testing logger")
      end
    end

    describe "#log_message" do
      it "adds the scheduler's identifier to the message" do
        @logger.log_message("testing").should == "[Recurrent - Process:logtastic - Timestamp:#{Time.now.to_s(:seconds)}] - testing"
      end
    end

  end
end
