require 'spec_helper'

describe Sidekiq::Worker do
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
  subject { DummySidekiqWorker }
  
  describe "#perform_async" do
    it "should push the job as normal" do
      subject.should_receive(:client_push).with('class' => subject, 'args' => [1, {'key' => 'value'}])
      subject.perform_async(1, 'key' => 'value')
    end
  end

  describe "#perform_async_without_before" do
    it "should push the job with skip_before option" do
      subject.should_receive(:client_push).with('class' => subject, 'args' => [1, {'key' => 'value'}], 'skip_before' => true)
      subject.perform_async_without_before(1, 'key' => 'value')
    end
  end
  
  describe "#perform_async_without_after" do
    it "should push the job with skip_after option" do
      subject.should_receive(:client_push).with('class' => subject, 'args' => [1, {'key' => 'value'}], 'skip_after' => true)
      subject.perform_async_without_after(1, 'key' => 'value')
    end
  end
  
  describe "#perform_async_without_callbacks" do
    it "should push the job with skip_before and skip_after option" do
      subject.should_receive(:client_push).with('class' => subject, 'args' => [1, {'key' => 'value'}], 'skip_before' => true, 'skip_after' => true)
      subject.perform_async_without_callbacks(1, 'key' => 'value')
    end
  end

  let(:later) { @later ||= 1.hour.from_now }
  describe "#perform_in" do
    it "should push the job as normal" do
      subject.should_receive(:client_push).with('class' => subject, 'args' => [1, {'key' => 'value'}], 'at' => later.to_f)
      subject.perform_in(later, 1, 'key' => 'value')
    end
  end

  describe "#perform_in_without_before" do
    it "should push the job with skip_before option" do
      subject.should_receive(:client_push).with('class' => subject, 'args' => [1, {'key' => 'value'}], 'at' => later.to_f, 'skip_before' => true)
      subject.perform_in_without_before(later, 1, 'key' => 'value')
    end
  end

  describe "#perform_in_without_after" do
    it "should push the job with skip_after option" do
      subject.should_receive(:client_push).with('class' => subject, 'args' => [1, {'key' => 'value'}], 'at' => later.to_f, 'skip_after' => true)
      subject.perform_in_without_after(later, 1, 'key' => 'value')
    end
  end

  describe "#perform_in_without_callbacks" do
    it "should push the job with skip_before and skip_after option" do
      subject.should_receive(:client_push).with('class' => subject, 'args' => [1, {'key' => 'value'}], 'at' => later.to_f, 'skip_before' => true, 'skip_after' => true)
      subject.perform_in_without_callbacks(later, 1, 'key' => 'value')
    end
  end
end
