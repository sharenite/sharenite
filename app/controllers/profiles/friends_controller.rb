# frozen_string_literal: true

# Friends controller
module Profiles
  # Profiles friends controller
  class FriendsController < BaseController
    before_action :check_current_user_profile, only: %i[index accept decline cancel]
    before_action :check_friendly_access_profile, only: %i[invite]

    def index
      set_friends
      set_invitations
      render :index
    end

    def show
    end

    def edit
    end

    def update
    end

    def destroy
    end

    # rubocop:disable all
    def invite
      other_user_id = Profile.friendly.find(params[:profile_id]).user.id
      if current_user.id == other_user_id
        flash[:error] = "Can't invite yourself."
      else
        friend = Friend.find_by(inviter_id: other_user_id, invitee_id: current_user.id)
        friend ||= Friend.find_or_create_by!(inviter_id: current_user.id, invitee_id: other_user_id)
        friend ||= Friend.find_or_create_by!(inviter_id: other_user_id, invitee_id: current_user.id)
        if friend.status_invited?
          flash[:success] = "User was invited to friends."
          friend.update(status: :invited)
        elsif friend.status_declined? && friend.invitee_id == current_user.id
          flash[:success] = "User was added to friends."
          friend.update(status: :accepted)
        elsif friend.status_accepted?
          flash[:notice] = "User is already a friend."
        else
          flash[:error] = "There's already an existing invitation that's either pending or declined by invitee."
        end
      end
      redirect_to profile_friends_path(current_user.profile)
    end

    def accept
      friend = Friend.find_by(id: params[:id])
      if friend && friend.invitee_id == current_user.id && friend.status_invited?
        flash[:success] = "Invitation was accepted."
        friend.update(status: :accepted)
      else
        flash[:error] = "Invitation was not found."
      end
      redirect_to profile_friends_path
    end

    def decline
      friend = Friend.find_by(id: params[:id])
      if friend && friend.invitee_id == current_user.id && friend.status_invited?
        flash[:notice] = "Invitation was declined, further invitations will not be possible unless you're the one inviting."
        friend.update(status: :declined)
      else
        flash[:error] = "Invitation was not found."
      end
      redirect_to profile_friends_path
    end

    def cancel
      friend = Friend.find_by(id: params[:id])
      if friend && friend.inviter_id == current_user.id && friend.status_invited?
        flash[:notice] = "Invitation was cancelled."
        friend.destroy
      else
        flash[:error] = "Invitation was not found."
      end
      redirect_to profile_friends_path
    end
    # rubocop:enable all

    private

    def set_friends
      @friends = Profile.where(user: @profile.user.friends).where.not(privacy: :private)
    end

    def set_invitations
      @invitations_received = @profile.user.pending_inviters
      @invitations_sent = @profile.user.pending_invitees
    end
  end
end
