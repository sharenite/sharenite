# frozen_string_literal: true

# Resolves relationship states between users based on Friend relations.
class FriendshipStateResolver
  STATE_PRIORITY = {
    you_declined: 10,
    invite_declined: 20,
    invite_received: 30,
    invite_sent: 40,
    friends: 50
  }.freeze

  class << self
    def relations_scope(current_user_id:, user_ids:)
      Friend.where(
        "(inviter_id = :current_id AND invitee_id IN (:user_ids)) OR (invitee_id = :current_id AND inviter_id IN (:user_ids))",
        current_id: current_user_id,
        user_ids:
      )
    end

    def relation_scope_with_user(current_user_id:, other_user_id:)
      Friend.where(
        "(inviter_id = :current_id AND invitee_id = :other_id) OR (inviter_id = :other_id AND invitee_id = :current_id)",
        current_id: current_user_id,
        other_id: other_user_id
      )
    end

    def states_for_users(current_user_id:, user_ids:)
      ids = Array(user_ids).compact.uniq - [current_user_id]
      return {} if ids.empty?

      other_user_id_sql = other_user_sql_for(current_user_id)
      state_priority_sql = state_priority_sql_for(current_user_id)

      relations_scope(current_user_id:, user_ids: ids)
        .group(Arel.sql(other_user_id_sql))
        .maximum(Arel.sql(state_priority_sql))
        .transform_values { |priority| state_from_priority(priority) }
        .compact
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def state_from_relations(relations:, current_user_id:)
      return nil if relations.blank?

      return :friends if relations.any?(&:status_accepted?)
      return :invite_sent if relations.any? { |relation| relation.status_invited? && relation.inviter_id == current_user_id }
      return :invite_received if relations.any? { |relation| relation.status_invited? && relation.invitee_id == current_user_id }
      return :invite_declined if relations.any? { |relation| relation.status_declined? && relation.inviter_id == current_user_id }
      return :you_declined if relations.any? { |relation| relation.status_declined? && relation.invitee_id == current_user_id }

      nil
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def state_from_priority(priority)
      case priority.to_i
      when STATE_PRIORITY[:friends] then :friends
      when STATE_PRIORITY[:invite_sent] then :invite_sent
      when STATE_PRIORITY[:invite_received] then :invite_received
      when STATE_PRIORITY[:invite_declined] then :invite_declined
      when STATE_PRIORITY[:you_declined] then :you_declined
      end
    end

    private

    def other_user_sql_for(current_user_id)
      quoted_current_id = ActiveRecord::Base.connection.quote(current_user_id)
      "CASE WHEN inviter_id = #{quoted_current_id} THEN invitee_id ELSE inviter_id END"
    end

    def state_priority_sql_for(current_user_id)
      quoted_current_id = ActiveRecord::Base.connection.quote(current_user_id)
      <<~SQL.squish
        CASE
          WHEN status = 'accepted' THEN #{STATE_PRIORITY[:friends]}
          WHEN status = 'invited' AND inviter_id = #{quoted_current_id} THEN #{STATE_PRIORITY[:invite_sent]}
          WHEN status = 'invited' AND invitee_id = #{quoted_current_id} THEN #{STATE_PRIORITY[:invite_received]}
          WHEN status = 'declined' AND inviter_id = #{quoted_current_id} THEN #{STATE_PRIORITY[:invite_declined]}
          WHEN status = 'declined' AND invitee_id = #{quoted_current_id} THEN #{STATE_PRIORITY[:you_declined]}
          ELSE 0
        END
      SQL
    end
  end
end
