require production_code
require 'support/messaging_helper'
require 'support/celluloid_hooks'

describe Hollywood::MessagingWrapper, :celluloid do
  let(:wrapped)        { double "wrapped",  { :update => true } }
  let(:input_channel)  { "input_channel" }
  let(:other_channel)  { "other_channel" }
  let(:output_channel) { "output_channel" }

  subject! { Hollywood::MessagingWrapper.new(wrapped, input_channel, output_channel) }

  describe "#wraps" do
    it 'wraps the given object' do
      expect(subject.wraps).to eq wrapped
    end
  end

  describe "messaging" do
    let!(:listener) { MessageHelper.new(output_channel) }
    let(:some_data) { double(:some_data) }

    it 'calls wrapped#update when receiving a message on a subscribed channel' do
      MessageHelper.new.publish(input_channel, some_data)
      expect(wrapped).to have_received :update
    end

    it 'does not update for messages on non-subscribed channels' do
      MessageHelper.new.publish(other_channel, some_data)
      expect(wrapped).to_not have_received :update
    end

    it 'announces on the output channel if the wrapper returns a value' do
      MessageHelper.new.publish(input_channel, :update)
      expect(listener).to be_updated
    end

    it 'does not announce if the wrapped object returns nil' do
      wrapped.stub(update: nil)
      MessageHelper.new.publish(input_channel, :update)
      expect(listener).to_not be_updated
    end

    it 'annouces contain the returned valued in the message' do
      wrapped.stub(update: some_data)
      MessageHelper.new.publish(input_channel, :update)
      expect(listener).to receive(:handle_message).with(some_data)
      puts log_output
    end

    it 'dies if the wrapped class exceptions' do
      wrapped.stub(:update){raise 'some error'}
      MessageHelper.new.publish(input_channel, :update)
      expect(subject).to_not be_alive
    end

    it 'listens for updates on multiple queues' do
      subject.depends_on 'foo'
      MessageHelper.new.publish('input_channel', :updated)
      MessageHelper.new.publish('foo', :updated)
      expect(wrapped).to have_received(:update).twice
    end
  end

  it 'throws an exception if the wrapped object does not respond to #update' do
    expect { Hollywood::MessagingWrapper.new( double('un-updateable'), input_channel, output_channel)}.to raise_error "Cannot wrap an object which doesn't provide #update"
  end

  describe '#new' do
    it 'can optionally be created with multiple input channels' do
      Hollywood::MessagingWrapper.new(wrapped, ['input_1', 'input_2'], output_channel)
      MessageHelper.new.publish('input_1', :updated)
      MessageHelper.new.publish('input_2', :updated)
      expect(wrapped).to have_received(:update).twice
    end
  end

  describe '#to_s' do
    it 'mentions the wrapped class' do
      expect(subject.to_s).to eq "Hollywood::MessagingWrapper[#{wrapped.class}]"
    end
  end

  describe 'logging' do
    it 'logs when it receives a message' do
      MessageHelper.new.publish(input_channel,:update)
      sleep 0.1
      log_output.should include "<- #{input_channel}:update"
    end

    it 'logs when it sends a message' do
      MessageHelper.new.publish(input_channel,:update)
      sleep 0.1
      log_output.should include "-> #{output_channel}:true"
    end
  end
end
