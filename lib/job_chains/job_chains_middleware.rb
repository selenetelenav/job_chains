class JobChainsMiddleware
  def initialize(options = {})
    @check_attempts = options[:attempts] || 3
    @retry_seconds = options[:retry_seconds] || 300
  end
  
  def call(worker, msg, queue)
    if worker.kind_of? Sidekiq::Extensions::DelayedClass
      # No handling for delayed jobs
      yield
    else
      args = msg["args"] || []
      return unless check_preconditions(worker, args)
      yield
      check_postconditions(worker, args)
    end
  end
  
  # Check preconditions in Sidekiq jobs
  def check_preconditions(worker, args)
    return true unless worker.respond_to? :before
    if args[-1].kind_of?(Hash)
      params = args[-1]
    else
      params = {}
      args << params
    end
    
    begin
      attempts = params['precondition_checks'].to_i
    rescue
      attempts = 1
    end

    unless before_passed?(worker)
      attempts += 1
      if attempts > @check_attempts
        error_message = "Attempted #{worker.class}, but preconditions were never met!"
        Honeybadger.notify(:error_message => error_message, :parameters => {:args => args})
      else
        params['precondition_checks'] = attempts
        Sidekiq::Client.enqueue_in(@retry_seconds.seconds, worker.class, *args)
        Rails.logger.info("Pre-conditions for #{worker.class} failed, delaying by #{@retry_seconds} seconds.")
      end
      return false
    end
    true
  end
  
  # Check postconditions in Sidekiq jobs
  def check_postconditions(worker, args)
    return true unless worker.respond_to? :after
    attempts = 1
    attempts += 1 until attempts > @check_attempts || after_passed?(worker)
    if attempts > @check_attempts
      error_message = "Finished #{worker.class}, but postconditions failed!"
      Honeybadger.notify(:error_message => error_message, :parameters => {:args => args})
      return false
    end
    true
  end
  
  private
  def before_passed?(worker)
    worker.before
  rescue => e
    Honeybadger.notify(e)
    false
  end

  def after_passed?(worker)
    worker.after
  rescue
    Honeybadger.notify(e)
    false
  end
end
