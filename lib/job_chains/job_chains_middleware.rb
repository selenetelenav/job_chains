class JobChainsMiddleware
  # Sidekiq default
  DEFAULT_MAX_RETRY_ATTEMPTS = 25
  
  def call(worker, msg, queue)
    if worker.kind_of? Sidekiq::Extensions::DelayedClass
      # No handling for delayed jobs
      yield
    else
      if check_preconditions(worker, msg)
        yield
        check_postconditions(worker, msg)
      end
    end
  end
  
  # Check preconditions in Sidekiq jobs
  def check_preconditions(worker, msg)
    return true unless worker.respond_to? :before
    return true if msg['skip_before'].to_s.downcase == 'true'


    if before_passed?(worker, msg)
      return true
    else
      max_retries = msg['retry'].try(:to_i) || DEFAULT_MAX_RETRY_ATTEMPTS
      retry_count = msg['retry_count'].try(:to_i) || 0
      msg['retry_count'] = retry_count + 1
      
      last_try = retry_count >= max_retries - 1

      if last_try
        worker.respond_to?(:before_failed) ? worker.before_failed : raise("Attempted #{worker.class.name}, but preconditions were never met!")
      else
        error_message = "Pre-conditions for #{worker.class.name}(#{msg['args'].join(',')}) failed."
        Rails.logger.info(error_message)
        # Will cause Honeybadger to ignore the error, but Sidekiq will retry the task
        raise SilentSidekiqError.new(error_message)
      end
      return false
    end
  end
  
  # Check postconditions in Sidekiq jobs
  def check_postconditions(worker, msg)
    return unless worker.respond_to? :after
    return if msg['skip_after'].to_s.downcase == 'true'

    max_retries = msg['retry'].try(:to_i) || DEFAULT_MAX_RETRY_ATTEMPTS
    attempts = 1
    attempts += 1 until after_passed?(worker, msg) || attempts > max_retries
    if attempts > max_retries
      error_message = "Finished #{worker.class.name}, but postconditions failed!"
      Honeybadger.notify_or_ignore(error_class: worker.class.name, error_message: error_message, parameters: msg)
    end
  end
  
  private
  def before_passed?(worker, msg)
    worker.before(*msg['args'])
  rescue => e
    Honeybadger.notify_or_ignore(error_class: worker.class.name, error_message: "Before hook threw error: #{e.message}", parameters: msg)
    false
  end

  def after_passed?(worker, msg)
    worker.after(*msg['args'])
  rescue => e
    Honeybadger.notify_or_ignore(error_class: worker.class.name, error_message: "After hook threw error: #{e.message}", parameters: msg)
    false
  end
end
