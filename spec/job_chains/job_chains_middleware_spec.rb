require 'spec_helper'

describe JobChainsMiddleware do
  subject { JobChainsMiddleware.new }
  
  class DummySidekiqWorker
    include Sidekiq::Worker
    
    def before
      true
    end
    
    def after
      true
    end
    
    def perform
      
    end
  end

  describe "#call" do
    context "with a DelayedClass worker" do
      before do
        @worker = Sidekiq::Extensions::DelayedClass.new
      end
      it "should yield without checking conditions" do
        subject.should_not_receive(:check_preconditions)
        subject.should_not_receive(:check_postconditions)
        subject.call(@worker, {}, 'default') {}
      end
    end
    context "with a normal Sidekiq worker" do
      before do
        @worker = DummySidekiqWorker.new
      end
      context "when the precondition check passes" do
        it "should yield and do postcondition check" do
          subject.should_receive(:check_preconditions).and_return(true)
          @worker.should_receive(:perform)
          subject.should_receive(:check_postconditions)
          subject.call(@worker, {}, 'default') { @worker.perform }
        end
      end
      context "when the precondition check throws a SilentSidekiqError" do
        it "should propogate the error" do
          subject.should_receive(:check_preconditions).and_raise(SilentSidekiqError)
          @worker.should_not_receive(:perform)
          subject.should_not_receive(:check_postconditions)
          
          expect {
            subject.call(@worker, {}, 'default') { @worker.perform }
          }.to raise_error(SilentSidekiqError)
        end
      end
      context "when the precondition check throws a RuntimeError" do
        it "should propogate the error" do
          subject.should_receive(:check_preconditions).and_raise("Runtime Error")
          @worker.should_not_receive(:perform)
          subject.should_not_receive(:check_postconditions)
          
          expect {
            subject.call(@worker, {}, 'default') { @worker.perform }
          }.to raise_error("Runtime Error")
        end
      end
    end
  end
  
  describe "#check_preconditions" do
    before do
      @worker = DummySidekiqWorker.new
    end
    context "when skip_before option is specified" do
      it "should not check before block" do
        @worker.should_not_receive(:before)
        subject.check_preconditions(@worker, 'skip_before' => 'true')
      end
    end
    context "when before block passes" do
      it "should return true and not raise an error" do
        @worker.should_receive(:before).and_return(true)
        subject.check_preconditions(@worker, {}).should be_true
      end
    end
    context "when before block returns false on the first attempt" do
      it "should log and raise a SilentSidekiqError" do
        @worker.should_receive(:before).and_return(false)
        Rails.logger.should_receive(:info)
        expect {
          subject.check_preconditions(@worker, 'retry_count' => '1', 'retry' => '5', 'args' => [])
        }.to raise_error(SilentSidekiqError)
      end
    end
    context "when before block returns false on the last attempt" do
      before { @worker.should_receive(:before).and_return(false) }
      context "when worker does not have before_failed defined" do
        it "should not log and raise a RuntimeError" do
          Rails.logger.should_not_receive(:info)
          expect {
            subject.check_preconditions(@worker, 'retry_count' => '5', 'retry' => '5', 'args' => [])
          }.to raise_error("Attempted #{@worker.class}, but preconditions were never met!")
        end
      end
      context "when worker has before_failed defined" do
        it "should return false and call before_failed" do
          @worker.should_receive(:before_failed)
          subject.check_preconditions(@worker, 'retry_count' => '5', 'retry' => '5', 'args' => []).should be_false
        end
      end
    end
    context "when before block throws an error on the first attempt" do
      it "should notify Honeybadger and raise a SilentSidekiqError" do
        @worker.should_receive(:before).and_raise('Runtime Error')
        Honeybadger.should_receive(:notify_or_ignore)
        expect {
          subject.check_preconditions(@worker, 'retry_count' => '1', 'retry' => '5', 'args' => [])
        }.to raise_error(SilentSidekiqError)
      end
    end
    context "when before block throws an error on the last attempt" do
      it "should notify Honeybadger and raise a Runtime Error" do
        @worker.should_receive(:before).and_raise('Runtime Error')
        Honeybadger.should_receive(:notify_or_ignore)
        expect {
          subject.check_preconditions(@worker, 'retry_count' => '5', 'retry' => '5', 'args' => [])
        }.to raise_error("Attempted #{@worker.class}, but preconditions were never met!")
      end
    end
  end
  
  describe "#check_postconditions" do
    before do
      @worker = DummySidekiqWorker.new
    end
    context "when skip_after option is specified" do
      it "should not check after block" do
        @worker.should_not_receive(:after)
        subject.check_preconditions(@worker, 'skip_after' => 'true', 'args' => [])
      end
    end
    context "when after block passes" do
      it "should succeed" do
        @worker.should_receive(:after).and_return(true)
        subject.check_postconditions(@worker, 'retry' => '5', 'args' => [])
      end
    end
    context "when after block fails then passes within max retires" do
      it "should succeed and not notify Honeybadger" do
        @worker.should_receive(:after).twice.and_return(false, true)
        Honeybadger.should_not_receive(:notify)
        subject.check_postconditions(@worker, 'retry' => '5', 'args' => [])
      end
    end    
    context "when after block fails max number of retries" do
      it "should notify Honeybadger and return false" do
        @worker.should_receive(:after).exactly(6).times.and_return(false)
        Honeybadger.should_receive(:notify_or_ignore)
        subject.check_postconditions(@worker, 'retry' => '5', 'args' => []).should be_false
      end
    end    
  end
end
