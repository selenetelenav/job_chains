module Sidekiq
  module Worker
    module ClassMethods

      def perform_async_without_before(*args)
        client_push('class' => self, 'args' => args, 'skip_before' => true)
      end

      def perform_async_without_after(*args)
        client_push('class' => self, 'args' => args, 'skip_after' => true)
      end

      def perform_async_without_callbacks(*args)
        client_push('class' => self, 'args' => args, 'skip_before' => true, 'skip_after' => true)
      end

      def perform_in_without_before(interval, *args)
        perform_in_helper({ 'skip_before' => true }, interval, *args)
      end
      alias_method :perform_at_without_before, :perform_in_without_before
      
      def perform_in_without_after(interval, *args)
        perform_in_helper({ 'skip_after' => true }, interval, *args)
      end
      alias_method :perform_at_without_after, :perform_in_without_after
      
      def perform_in_without_callbacks(interval, *args)
        perform_in_helper({ 'skip_before' => true, 'skip_after' => true }, interval, *args)
      end
      alias_method :perform_at_without_callbacks, :perform_in_without_callbacks
      
      private
      # Pulled straight from Sidekiq::Worker's perform_in definition, we need to be able to pass in additional args to
      # client_push for skipping callbacks
      def perform_in_helper(item, interval, *args)
        int = interval.to_f
        now = Time.now.to_f
        ts = (int < 1_000_000_000 ? now + int : int)

        item.merge!('class' => self, 'args' => args, 'at' => ts)

        # Optimization to enqueue something now that is scheduled to go out now or in the past
        item.delete('at') if ts <= now

        client_push(item)
      end
    end
  end
end
