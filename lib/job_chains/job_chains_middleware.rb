class JobChainsMiddleware
  def call(worker, msg, queue)
    if worker.kind_of? Sidekiq::Extensions::DelayedClass
      # No handling for delayed jobs
      yield
    else
      check_preconditions(worker, msg)
      yield
      check_postconditions(worker, msg)
    end
  end
  
  # Check preconditions in Sidekiq jobs
  def check_preconditions(worker, msg)
    return true unless worker.respond_to? :before
    args = msg['args'] || []
    unless before_passed?(worker, args)
      max_retries = msg['retry'] || Sidekiq::Middleware::Server::RetryJobs::DEFAULT_MAX_RETRY_ATTEMPTS
      retry_count = msg['retry_count'] || 0
      msg['retry_count'] = retry_count + 1
      
      last_try = retry_count >= max_retries - 1

      if last_try
        raise "Attempted #{worker.class}, but preconditions were never met!"
      else
        error_message = "Pre-conditions for #{worker.class}(#{args.join(',')}) failed."
        Rails.logger.info(error_message)
        # Will cause Honeybadger to ignore the error, but Sidekiq will retry the task
        raise SilentSidekiqError.new(error_message)
      end
    end
  end
  
  # Check postconditions in Sidekiq jobs
  def check_postconditions(worker, msg)
    return true unless worker.respond_to? :after
    args = msg['args'] || []
    max_retries = msg['retry'] || Sidekiq::Middleware::Server::RetryJobs::DEFAULT_MAX_RETRY_ATTEMPTS
    attempts = 1
    attempts += 1 until attempts > max_retries || after_passed?(worker, args)
    if attempts > max_retries
      error_message = "Finished #{worker.class}, but postconditions failed!"
      Honeybadger.notify(error_class: worker.class, error_message: error_message, parameters: {:args => args})
    end
  end
  
  private
  def before_passed?(worker, args)
    worker.before(*args)
  rescue => e
    Honeybadger.notify(error_class: worker.class, error_message: "Before hook threw error: #{e.message}", parameters: {:args => args })
    false
  end

  def after_passed?(worker, args)
    worker.after(*args)
  rescue
    Honeybadger.notify(error_class: worker.class, error_message: "After hook threw error: #{e.message}", parameters: {:args => args })
    false
  end
end
