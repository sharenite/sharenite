# frozen_string_literal: true

class NormalizeSyncJobChunkNameSpacing < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL.squish
      UPDATE sync_jobs
      SET name = regexp_replace(name, '^(.*)\(chunk ([0-9]+/[0-9]+)\)$', '\\1 (chunk \\2)')
      WHERE name ~ '^[^()]+\(chunk [0-9]+/[0-9]+\)$'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE sync_jobs
      SET name = regexp_replace(name, '^(.*) \(chunk ([0-9]+/[0-9]+)\)$', '\\1(chunk \\2)')
      WHERE name ~ '^[^()]+ \(chunk [0-9]+/[0-9]+\)$'
    SQL
  end
end
