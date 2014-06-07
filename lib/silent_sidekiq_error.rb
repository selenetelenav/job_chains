# Specific error to be thrown when Sidekiq retries a worker, without sending notifications
# For use by RetriesExhaustedMiddleware
class SilentSidekiqError < StandardError
  
end
