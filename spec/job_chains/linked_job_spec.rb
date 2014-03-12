require 'spec_helper'

describe LinkedJob do 
  class DummyLinkedJob
    extend LinkedJob
  end 

  describe "#before_perform_check_preconditions" do
    context "when before block passes" do
      it "should return check before block and do nothing" do
        DummyLinkedJob.should_receive(:before).and_return(true)
        DummyLinkedJob.before_perform_check_preconditions
      end
    end
    context "when before block fails on the first attempt" do
      it "should enqueue for later and raise DontPerform" do
        DummyLinkedJob.should_receive(:before).and_return(false)
        Honeybadger.should_not_receive(:notify)
        Resque.should_receive(:enqueue_in).with(5.minutes, DummyLinkedJob, 'precondition_checks' => 2)
        expect {
          DummyLinkedJob.before_perform_check_preconditions('precondition_checks' => '1')
        }.to raise_error Resque::Job::DontPerform
      end
    end
    context "when before block fails on the last attempt" do
      it "should notify Honeybadger and raise DontPerform" do
        DummyLinkedJob.should_receive(:before).and_return(false)
        Honeybadger.should_receive(:notify)
        Resque.should_not_receive(:enqueue_in)
        expect {
          DummyLinkedJob.before_perform_check_preconditions('precondition_checks' => '3')
        }.to raise_error Resque::Job::DontPerform
      end
    end
  end
  
  describe "#after_perform_check_postconditions" do
    context "when after block passes" do
      it "should do nothing" do
        DummyLinkedJob.should_receive(:after).and_return(true)
        Honeybadger.should_not_receive(:notify)
        DummyLinkedJob.after_perform_check_postconditions
      end
    end
    context "when after block fails then passes" do
      it "should do nothing" do
        DummyLinkedJob.should_receive(:after).twice.and_return(false, true)
        Honeybadger.should_not_receive(:notify)
        DummyLinkedJob.after_perform_check_postconditions
      end
    end    
    context "when after block fails" do
      it "should notify Honeybadger" do
        DummyLinkedJob.should_receive(:after).exactly(3).times.and_return(false)
        Honeybadger.should_receive(:notify)
        DummyLinkedJob.after_perform_check_postconditions
      end
    end    
  end
end
