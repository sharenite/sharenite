# frozen_string_literal: true

# Friends controller
module Profiles
  # Profiles friends controller
  # rubocop:disable Metrics/ClassLength
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
        relations = FriendshipStateResolver.relation_scope_with_user(
          current_user_id: current_user.id,
          other_user_id:
        )
        state = FriendshipStateResolver.state_from_relations(relations:, current_user_id: current_user.id)

        case state
        when :friends
          flash[:notice] = "User is already a friend."
        when :invite_sent
          flash[:notice] = "Invitation already sent."
        when :invite_received
          flash[:notice] = "User has already invited you. Accept or decline from Friends."
        when :invite_declined
          flash[:error] = "Your previous invitation was declined. Wait for this user to invite you."
        when :you_declined
          relation = relations.find { |item| item.status_declined? && item.invitee_id == current_user.id }
          relation ||= Friend.find_or_initialize_by(inviter_id: current_user.id, invitee_id: other_user_id)
          relation.update!(status: :accepted)
          flash[:success] = "User was added to friends."
        else
          Friend.create!(inviter_id: current_user.id, invitee_id: other_user_id, status: :invited)
          flash[:success] = "User was invited to friends."
        end
      end
      redirect_to profile_friends_path(current_user.profile, tab: redirect_tab("friends"))
    end

    def accept
      friend = Friend.find_by(id: params[:id])
      if friend && friend.invitee_id == current_user.id && friend.status_invited?
        flash[:success] = "Invitation was accepted."
        friend.update(status: :accepted)
      else
        flash[:error] = "Invitation was not found."
      end
      redirect_to profile_friends_path(current_user.profile, tab: redirect_tab("friends"))
    end

    def decline
      friend = Friend.find_by(id: params[:id])
      if friend && friend.invitee_id == current_user.id && friend.status_invited?
        flash[:notice] = "Invitation was declined, further invitations will not be possible unless you're the one inviting."
        friend.update(status: :declined)
      elsif friend && friend.invitee_id == current_user.id && friend.status_declined?
        flash[:notice] = "Invitation was already declined."
      else
        flash[:error] = "Invitation was not found."
      end
      redirect_to profile_friends_path(current_user.profile, tab: redirect_tab("declined"))
    end

    def cancel
      friend = Friend.find_by(id: params[:id])
      if friend && friend.inviter_id == current_user.id && friend.status_invited?
        flash[:notice] = "Invitation was cancelled."
        friend.destroy
      else
        flash[:error] = "Invitation was not found."
      end
      redirect_to profile_friends_path(current_user.profile, tab: redirect_tab("sent"))
    end
    # rubocop:enable all

    private

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def set_friends
      scope = Profile.where(user: @profile.user.friends)
                     .where.not(privacy: :private)
                     .joins(:user)
                     .left_joins(user: :games)
                     .select("profiles.*, COUNT(games.id) AS games_count")
                     .group("profiles.id")

      name_query = params[:search_name].to_s.strip
      scope = scope.where("profiles.name ILIKE ?", "%#{name_query}%") if name_query.present?

      games_from = parse_games_count_param(:games_from)
      games_to = parse_games_count_param(:games_to)

      scope = scope.having("COUNT(games.id) >= ?", games_from) unless games_from.nil?
      scope = scope.having("COUNT(games.id) <= ?", games_to) unless games_to.nil?

      @friends = scope.order("profiles.name ASC").page(params[:page]).per(25)
    end

    def set_invitations
      name_query = params[:search_name].to_s.strip
      games_from = parse_games_count_param(:games_from)
      games_to = parse_games_count_param(:games_to)
      any_filter = name_query.present? || games_from.present? || games_to.present?
      filtered_user_ids = any_filter ? filtered_user_ids_for_invitation_filters(name_query:, games_from:, games_to:) : nil

      @invitations_received = @profile.user.pending_inviters
                                     .includes(inviter: :profile)
                                     .order(created_at: :desc)
      @invitations_received = @invitations_received.where(inviter_id: filtered_user_ids) if any_filter

      @invitations_sent = @profile.user.pending_invitees
                                 .includes(invitee: :profile)
                                 .order(created_at: :desc)
      @invitations_sent = @invitations_sent.where(invitee_id: filtered_user_ids) if any_filter

      @invitations_declined = Friend.where(status: :declined)
                                    .where("inviter_id = :user_id OR invitee_id = :user_id", user_id: @profile.user.id)
                                    .includes(inviter: :profile, invitee: :profile)
                                    .order(updated_at: :desc)
      return unless any_filter

      @invitations_declined = @invitations_declined.where(
        "(inviter_id = :current_user_id AND invitee_id IN (:filtered_user_ids)) OR " \
        "(invitee_id = :current_user_id AND inviter_id IN (:filtered_user_ids))",
        current_user_id: @profile.user.id,
        filtered_user_ids:
      )
    end

    def parse_games_count_param(key)
      value = params[key].to_s.strip
      return if value.blank?

      parsed = Integer(value, 10)
      parsed.negative? ? nil : parsed
    rescue ArgumentError
      nil
    end

    def filtered_user_ids_for_invitation_filters(name_query:, games_from:, games_to:)
      scope = User.joins(:profile)
                  .left_joins(:games)
                  .select("users.id")
                  .group("users.id")

      scope = scope.where("profiles.name ILIKE ?", "%#{name_query}%") if name_query.present?
      scope = scope.having("COUNT(games.id) >= ?", games_from) if games_from.present?
      scope = scope.having("COUNT(games.id) <= ?", games_to) if games_to.present?

      scope.pluck(:id)
    end

    def redirect_tab(default_tab)
      allowed = %w[friends received sent declined]
      requested = params[:tab].to_s
      allowed.include?(requested) ? requested : default_tab
    end

    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  end
  # rubocop:enable Metrics/ClassLength
end
