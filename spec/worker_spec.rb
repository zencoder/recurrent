require 'spec_helper'

module Recurrent
  describe Worker do
    describe "#wait_until" do
      it "waits until a specified time" do
        Timecop.freeze(Time.local(2011, 7, 26, 11, 35, 00))
        waiting_thread = Thread.new { Worker.new.wait_until(Time.local(2011, 7, 26, 11, 40, 00)) }
        waiting_thread.alive?.should be_true
        Timecop.travel(Time.local(2011, 7, 26, 11, 40, 00))
        sleep(0.5)
        waiting_thread.alive?.should be_false
        Timecop.return
      end
    end
  end
end
