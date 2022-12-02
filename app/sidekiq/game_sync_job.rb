# frozen_string_literal: true

# Job that performs a full library sync asynchornously
class GameSyncJob
  include Sidekiq::Job
  sidekiq_options lock: :while_executing, unique_across_workers: true, lock_args_method: ->(args) { [args[2]] }, on_conflict: :reschedule

  def variables(args)
    @new_game = args[1]
    @user = User.find(args[2])
    @game = @user.games.find_by(playnite_id: args[0])
    @sync_job = SyncJob.find(args[3])
  end

  def perform(*_args)
    raise "Not implemented"
    # variables(args)
    # start_job
    # synchronise_game
    # finish_job
  end

  private

  def start_job
    @sync_job.status_running!
  end

  def finish_job
    @sync_job.status_finished!
  end

  def synchronise_game
    @game&.update(@new_game)
  end
end
