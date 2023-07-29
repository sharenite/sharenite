# frozen_string_literal: true
class Friend < ApplicationRecord
  belongs_to :invitee, class_name: 'User', inverse_of: :inviters
  belongs_to :inviter, class_name: 'User', inverse_of: :invitees

  enum status: { invited: "invited", accepted: "accepted", declined: "declined" }, _prefix: :status

  def self.ransackable_attributes(_auth_object = nil)
    ["created_at", "id", "invitee_id", "inviter_id", "status", "updated_at"]
  end
end
