# frozen_string_literal: true

# Adds diagnostics fields used to inspect sync payload and failure details.
class AddSyncJobDiagnostics < ActiveRecord::Migration[7.1]
  def change
    change_table :sync_jobs, bulk: true do |t|
      t.bigint :payload_size_bytes, null: false, default: 0
      t.integer :payload_chunks, null: false, default: 1
      t.integer :payload_chunk_index, null: false, default: 0
      t.text :error_message
    end
  end
end
