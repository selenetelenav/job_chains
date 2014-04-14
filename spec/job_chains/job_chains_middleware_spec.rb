require 'spec_helper'

describe JobChainsMiddleware do
  subject { JobChainsMiddleware.new }
  
  class DummySidekiqWorker
    extend Sidekiq::Worker
    
    def before
      true
    end
    
    def after
      true
    end
    
    def check_attempts
      5
    end

    def retry_seconds
      10
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
      context "when it fails precondition check" do
        it "should not do anything" do
          subject.should_receive(:check_preconditions).and_return(false)
          @worker.should_not_receive(:perform)
          subject.should_not_receive(:check_postconditions)
          subject.call(@worker, {}, 'default') { @worker.perform }
        end
      end
      context "when it passes precondition check" do
        it "should yield and do postcondition check" do
          subject.should_receive(:check_preconditions).and_return(true)
          @worker.should_receive(:perform)
          subject.should_receive(:check_postconditions)
          subject.call(@worker, {}, 'default') { @worker.perform }
        end
      end
    end
  end
  
  describe "#check_preconditions" do
    before do
      @worker = DummySidekiqWorker.new
    end
    context "when before block passes" do
      it "should return true" do
        @worker.should_receive(:before).and_return(true)
        subject.check_preconditions(@worker, [{}]).should be_true
      end
    end
    context "when before block fails on the first attempt" do
      it "should enqueue for later and return false" do
        @worker.should_receive(:before).and_return(false)
        Honeybadger.should_not_receive(:notify)
        Sidekiq::Client.should_receive(:enqueue_in).with(10.seconds, DummySidekiqWorker, 'precondition_checks' => 2)
        subject.check_preconditions(@worker, ['precondition_checks' => '1']).should be_false
      end
    end
    context "when before block fails on the last attempt" do
      it "should notify Honeybadger and return false" do
        @worker.should_receive(:before).and_return(false)
        Honeybadger.should_receive(:notify)
        Sidekiq::Client.should_not_receive(:enqueue_in)
        subject.check_preconditions(@worker, ['precondition_checks' => '5']).should be_false
      end
    end
  end
  
  describe "#check_postconditions" do
    before do
      @worker = DummySidekiqWorker.new
    end
    context "when after block passes" do
      it "should return true" do
        @worker.should_receive(:after).and_return(true)
        subject.check_postconditions(@worker, [{}]).should be_true
      end
    end
    context "when after block fails then passes" do
      it "should return true" do
        @worker.should_receive(:after).twice.and_return(false, true)
        Honeybadger.should_not_receive(:notify)
        subject.check_postconditions(@worker, [{}]).should be_true
      end
    end    
    context "when after block fails" do
      it "should notify Honeybadger and return false" do
        @worker.should_receive(:after).exactly(5).times.and_return(false)
        Honeybadger.should_receive(:notify)
        subject.check_postconditions(@worker, [{}]).should be_false
      end
    end    
  end
end
