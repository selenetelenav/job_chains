require 'bundler/setup'
Bundler.setup

require 'rails/all'
require 'rspec/rails'
require 'job_chains'
require 'honeybadger'
require 'resque'
require 'sidekiq'
require 'rspec-sidekiq'
require 'sidekiq/testing'

Rails.logger ||= Logger.new('/dev/null')

RSpec.configure do |config|
  RSpec::Sidekiq.configure { |config| config.warn_when_jobs_not_processed_by_sidekiq = false }
  Sidekiq::Testing.fake!
end
