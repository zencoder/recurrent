require 'spec_helper'

module Recurrent
  describe Logger do
    before(:all) do
      @logger = Logger.new('logtastic')
    end

    describe "#log" do
      context "when a logger is configured" do
        it "should send a message to the logger" do
          some_logger = stub('logger')
          some_logger.should_receive(:info).with(@logger.log_message("testing logger"))
          Configuration.logger do |message|
            some_logger.info(message)
          end
          @logger.log("testing logger")
          Configuration.logger = nil
        end
      end
    end

    describe "#log_message" do
      it "adds the scheduler's identifier to the message" do
        @logger.log_message("testing").should == "[Recurrent - Process:logtastic - Timestamp:#{Time.now.to_s(:seconds)}] - testing"
      end
    end

  end
end
