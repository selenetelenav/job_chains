module LinkedJob
  def before
    true
  end
  
  def after
    true
  end

  def check_attempts
    3
  end
  
  def retry_seconds
    300
  end
  
  # Check preconditions in Resque jobs
  def before_perform_check_preconditions(*args)
    if args[-1].kind_of?(Hash)
      params = args[-1]
    else
      params = {}
      args << params
    end
    attempts = params['precondition_checks'].try(:to_i) || 1
    unless before_passed?
      attempts += 1
      if attempts > check_attempts
        error_message = "Attempted #{self}, but preconditions were never met!"
        Honeybadger.notify(:error_message => error_message, :parameters => {:args => args})
      else
        params['precondition_checks'] = attempts
        Resque.enqueue_in(retry_seconds, self, *args)
        Rails.logger.info("Pre-conditions for #{self} failed, delaying by #{retry_seconds} seconds.")
      end
      raise Resque::Job::DontPerform
    end
  end
  
  # Check postconditions in Resque jobs
  def after_perform_check_postconditions(*args)
    attempts = 1
    attempts += 1 until attempts > check_attempts || after_passed?
    if attempts > check_attempts
      error_message = "Finished #{self}, but postconditions failed!"
      Honeybadger.notify(:error_message => error_message, :parameters => {:args => args})
    end
  end
  
  protected
  def before_passed?
    before
  rescue => e
    Honeybadger.notify(e)
    false
  end
  
  def after_passed?
    after
  rescue => e
    Honeybadger.notify(e)
    false
  end
end
