# integrates Logtail::CurrentContext with Sidekiq::Context if installed

begin
  require 'sidekiq/job_logger'

  class Sidekiq::JobLogger
    def call(_item, _queue)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      Logtail::CurrentContext.with({ sidekiq: Sidekiq::Context.current.to_h }) do
        @logger.info("start")

        yield
      end

      Sidekiq::Context.add(:elapsed, elapsed(start))
      Logtail::CurrentContext.with({ sidekiq: Sidekiq::Context.current.to_h }) do
        @logger.info('done')
      end
    rescue Exception
      Sidekiq::Context.add(:elapsed, elapsed(start))
      Logtail::CurrentContext.with({ sidekiq: Sidekiq::Context.current.to_h }) do
        @logger.info('fail')
      end

      raise
    end

    private

    def elapsed(start)
      (Process.clock_gettime(::Process::CLOCK_MONOTONIC) - start).round(3)
    end
  end

rescue LoadError
  # sidekiq is not present
end
