require 'benchmark'
require 'fileutils'
require 'health_checks/checks/memory_check'
require 'health_checks/checks/mongoid_check'
require 'health_checks/checks/redis_check'

module HealthChecks
  module_function

  def sidekiq(config, mongo_databases, redis_configs, sleep_seconds: 10)
    config.on(:startup) do
      LivenessThreadCheck.new.start(mongo_databases, redis_configs, sleep_seconds)
    end
  end

  private

  STATUS_FILE = '/tmp/sidekiq_ok'

  class LivenessThreadCheck
    def start(mongo_databases, redis_configs, sleep_seconds)
      logger = Sidekiq::Logging.logger

      logger.info "Starting liveness thread with #{sleep_seconds} sleep delay"

      checks = mongo_databases.map { |db| Checks::MongoidCheck.new(db) }
      checks += redis_configs.map{ |config| Checks::RedisCheck.new(config) }
      # checks << Checks::MemoryCheck.new

      Thread.new do
        elapsed_time = 0

        failed = false

        checks.each do |check|
          elapsed_time = Benchmark.measure { check.run }
          logger.info "Time elapsed for #{check} was #{elapsed_time}"
        rescue => e
          logger.error e
          logger.info "Time elapsed for #{check} was #{elapsed_time}"

          failed = true
          break
        end

        failed ? handle_fail : handle_success

        sleep sleep_seconds
      end
    end

    def handle_fail
      FileUtils.rm(STATUS_FILE)
    end

    def handle_success
      FileUtils.touch(STATUS_FILE)
    end
  end
end
