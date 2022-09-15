# frozen_string_literal: true
class Friend < ApplicationRecord
  belongs_to :invitee, class_name: 'User', inverse_of: :inviters
  belongs_to :inviter, class_name: 'User', inverse_of: :invitees

  enum status: { invited: "invited", accepted: "accepted", declined: "declined" }, _prefix: :status
end
