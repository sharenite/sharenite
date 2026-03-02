# frozen_string_literal: true

# Resolves relationship states between users based on Friend relations.
class FriendshipStateResolver
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
  end
end
