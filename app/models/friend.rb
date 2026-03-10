# frozen_string_literal: true

# Represents a friendship invitation/relationship between two users.
class Friend < ApplicationRecord
  attr_accessor :inviter_query, :invitee_query

  belongs_to :invitee, class_name: 'User', inverse_of: :inviters
  belongs_to :inviter, class_name: 'User', inverse_of: :invitees

  enum status: { invited: "invited", accepted: "accepted", declined: "declined", blocked: "blocked" }, _prefix: :status

  def self.ransackable_attributes(_auth_object = nil)
    ["created_at", "id", "invitee_id", "inviter_id", "status", "updated_at"]
  end

  def self.ransackable_associations(_auth_object = nil)
    ["invitee", "inviter"]
  end
end
