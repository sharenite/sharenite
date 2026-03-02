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
        relations = relations_with_user(other_user_id)
        state = friendship_state_from_relations(relations)

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

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
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
      name_query = params[:search_name].to_s.strip.downcase
      games_from = parse_games_count_param(:games_from)
      games_to = parse_games_count_param(:games_to)

      @invitations_received = @profile.user.pending_inviters
                                     .includes(inviter: %i[profile games])
                                     .order(created_at: :desc)
                                     .select do |invitation|
        invitation_matches_filters?(invitation.inviter, name_query, games_from, games_to)
      end

      @invitations_sent = @profile.user.pending_invitees
                                 .includes(invitee: %i[profile games])
                                 .order(created_at: :desc)
                                 .select do |invitation|
        invitation_matches_filters?(invitation.invitee, name_query, games_from, games_to)
      end

      @invitations_declined = Friend.where(status: :declined)
                                    .where("inviter_id = :user_id OR invitee_id = :user_id", user_id: @profile.user.id)
                                    .includes(inviter: %i[profile games], invitee: %i[profile games])
                                    .order(updated_at: :desc)
                                    .select do |relation|
        invitation_matches_filters?(declined_counterparty(relation), name_query, games_from, games_to)
      end
    end

    def parse_games_count_param(key)
      value = params[key].to_s.strip
      return if value.blank?

      parsed = Integer(value, 10)
      parsed.negative? ? nil : parsed
    rescue ArgumentError
      nil
    end

    def invitation_matches_filters?(user, name_query, games_from, games_to)
      profile_name = user.profile&.name.to_s.downcase
      return false if name_query.present? && profile_name.exclude?(name_query)

      games_count = user.games.size
      return false if games_from.present? && games_count < games_from
      return false if games_to.present? && games_count > games_to

      true
    end

    def declined_counterparty(relation)
      relation.inviter_id == @profile.user.id ? relation.invitee : relation.inviter
    end

    def redirect_tab(default_tab)
      allowed = %w[friends received sent declined]
      requested = params[:tab].to_s
      allowed.include?(requested) ? requested : default_tab
    end

    def relations_with_user(other_user_id)
      Friend.where(
        "(inviter_id = :current_id AND invitee_id = :other_id) OR (inviter_id = :other_id AND invitee_id = :current_id)",
        current_id: current_user.id,
        other_id: other_user_id
      )
    end

    def friendship_state_from_relations(relations)
      return nil if relations.blank?

      return :friends if relations.any?(&:status_accepted?)
      return :invite_sent if relations.any? { |relation| relation.status_invited? && relation.inviter_id == current_user.id }
      return :invite_received if relations.any? { |relation| relation.status_invited? && relation.invitee_id == current_user.id }
      return :invite_declined if relations.any? { |relation| relation.status_declined? && relation.inviter_id == current_user.id }
      return :you_declined if relations.any? { |relation| relation.status_declined? && relation.invitee_id == current_user.id }

      nil
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  end
  # rubocop:enable Metrics/ClassLength
end
