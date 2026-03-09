# frozen_string_literal: true

class CreateRequestThrottleEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :request_throttle_events, id: :uuid do |t|
      t.string :event_type, null: false
      t.string :rule_name, null: false
      t.string :actor_type, null: false
      t.string :actor_key, null: false
      t.uuid :user_id
      t.string :ip_address, null: false
      t.string :request_method, null: false
      t.string :request_path, null: false
      t.integer :limit_value, null: false
      t.integer :period_seconds, null: false
      t.integer :hit_count, null: false, default: 1
      t.integer :peak_count, null: false, default: 0
      t.integer :escalation_value
      t.boolean :permanent, null: false, default: false
      t.datetime :started_at, null: false
      t.datetime :last_seen_at, null: false
      t.datetime :expires_at
      t.datetime :lifted_at
      t.timestamps
    end

    add_index :request_throttle_events, :event_type
    add_index :request_throttle_events, :rule_name
    add_index :request_throttle_events, :actor_key
    add_index :request_throttle_events, :user_id
    add_index :request_throttle_events, :ip_address
    add_index :request_throttle_events, :started_at
    add_index :request_throttle_events, :expires_at
    add_index :request_throttle_events, :lifted_at
    add_index :request_throttle_events, %i[event_type permanent lifted_at expires_at], name: "index_request_throttle_events_on_state_columns"
    add_foreign_key :request_throttle_events, :users
  end
end
