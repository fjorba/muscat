class PurgeSearchesJob < ActiveJob::Base
  queue_as :default

  def perform(*args)
    Search.delete_old_searches(7)
  end
end
