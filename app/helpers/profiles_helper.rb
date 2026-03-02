# frozen_string_literal: true
# Profiles helper
module ProfilesHelper
  def profile_friendship_state_label(state)
    {
      friends: "Friends",
      invite_sent: "Invite sent",
      invite_received: "Invite received",
      invite_declined: "Invite declined",
      you_declined: "You declined"
    }[state&.to_sym]
  end

  def profile_friendship_state_class(state)
    case state&.to_sym
    when :friends
      "profiles-info-pill profiles-info-pill-success"
    when :invite_sent, :invite_received
      "profiles-info-pill profiles-info-pill-info"
    when :invite_declined, :you_declined
      "profiles-info-pill profiles-info-pill-muted"
    end || "profiles-info-pill"
  end
end
