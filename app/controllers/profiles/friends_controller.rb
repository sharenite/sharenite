# frozen_string_literal: true

# Friends controller
module Profiles
  # Profiles friends controller
  # rubocop:disable Metrics/ClassLength
  class FriendsController < BaseController
    TABS = %w[friends received sent declined].freeze

    before_action :check_current_user_profile, only: %i[index accept decline cancel]
    before_action :check_friendly_access_profile, only: %i[invite]

    def index
      @active_tab = active_tab
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

    # rubocop:disable Metrics/AbcSize
    def set_friends
      scope = base_friends_scope

      name_query = params[:search_name].to_s.strip
      scope = scope.where("profiles.name ILIKE ?", "%#{name_query}%") if name_query.present?

      games_from = parse_games_count_param(:games_from)
      games_to = parse_games_count_param(:games_to)

      scope = apply_games_count_filter(scope, games_from:, games_to:)

      ordered_scope = scope.order("profiles.name ASC")
      @friends_total_count = normalize_count_result(ordered_scope.except(:select, :order).count)
      @friends = if @active_tab == "friends"
                   ordered_scope.page(params[:page]).per(25)
                 else
                   Profile.none.page(params[:page]).per(25)
                 end
    end

    def set_invitations
      name_query = params[:search_name].to_s.strip
      games_from = parse_games_count_param(:games_from)
      games_to = parse_games_count_param(:games_to)
      any_filter = name_query.present? || games_from.present? || games_to.present?
      filtered_user_ids = any_filter ? filtered_user_ids_for_invitation_filters(name_query:, games_from:, games_to:) : nil

      received_scope = invitation_received_scope(any_filter:, filtered_user_ids:)
      @invitations_received_count = received_scope.count
      @invitations_received = @active_tab == "received" ? received_scope.load : []

      sent_scope = invitation_sent_scope(any_filter:, filtered_user_ids:)
      @invitations_sent_count = sent_scope.count
      @invitations_sent = @active_tab == "sent" ? sent_scope.load : []

      declined_scope = invitation_declined_scope(any_filter:, filtered_user_ids:)
      @invitations_declined_count = declined_scope.count
      @invitations_declined = @active_tab == "declined" ? declined_scope.load : []
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
                  .select(:id)

      scope = scope.where("profiles.name ILIKE ?", "%#{name_query}%") if name_query.present?
      apply_user_games_count_filter(scope, games_from:, games_to:)
    end

    def redirect_tab(default_tab)
      requested = params[:tab].to_s
      TABS.include?(requested) ? requested : default_tab
    end

    def active_tab
      requested = params[:tab].to_s
      TABS.include?(requested) ? requested : "friends"
    end

    def invitation_received_scope(any_filter:, filtered_user_ids:)
      scope = @profile.user.pending_inviters
                      .includes(inviter: :profile)
                      .order(created_at: :desc)
      return scope unless any_filter

      scope.where(inviter_id: filtered_user_ids)
    end

    def invitation_sent_scope(any_filter:, filtered_user_ids:)
      scope = @profile.user.pending_invitees
                      .includes(invitee: :profile)
                      .order(created_at: :desc)
      return scope unless any_filter

      scope.where(invitee_id: filtered_user_ids)
    end

    def invitation_declined_scope(any_filter:, filtered_user_ids:)
      scope = Friend.where(status: :declined)
                    .where("inviter_id = :user_id OR invitee_id = :user_id", user_id: @profile.user.id)
                    .includes(inviter: :profile, invitee: :profile)
                    .order(updated_at: :desc)
      return scope unless any_filter

      scope.where(
        "(inviter_id = :current_user_id AND invitee_id IN (:filtered_user_ids)) OR " \
        "(invitee_id = :current_user_id AND inviter_id IN (:filtered_user_ids))",
        current_user_id: @profile.user.id,
        filtered_user_ids:
      )
    end

    def accepted_friend_user_ids_scope
      user_id = @profile.user.id
      quoted_user_id = ActiveRecord::Base.connection.quote(user_id)
      sql = "DISTINCT CASE WHEN inviter_id = #{quoted_user_id} THEN invitee_id ELSE inviter_id END"
      Friend.where(status: :accepted)
            .where("inviter_id = :user_id OR invitee_id = :user_id", user_id:)
            .select(Arel.sql(sql))
    end

    def base_friends_scope
      scope = Profile.where(user_id: accepted_friend_user_ids_scope)
                     .where.not(privacy: :private)
                     .joins(:user)
      return scope.select("profiles.*, COALESCE(users.games_count, 0) AS games_count") if User.games_count_available?

      scope.left_joins(user: :games)
           .select("profiles.*, COUNT(games.id) AS games_count")
           .group("profiles.id")
    end

    def apply_games_count_filter(scope, games_from:, games_to:)
      return scope if games_from.nil? && games_to.nil?

      comparator = User.games_count_available? ? "COALESCE(users.games_count, 0)" : "COUNT(games.id)"
      apply_games_count_bounds(scope, comparator:, games_from:, games_to:)
    end

    def apply_games_count_bounds(scope, comparator:, games_from:, games_to:)
      if User.games_count_available?
        scope = scope.where("#{comparator} >= ?", games_from) unless games_from.nil?
        return scope.where("#{comparator} <= ?", games_to) unless games_to.nil?

        return scope
      end

      scope = scope.having("#{comparator} >= ?", games_from) unless games_from.nil?
      return scope.having("#{comparator} <= ?", games_to) unless games_to.nil?

      scope
    end

    def apply_user_games_count_filter(scope, games_from:, games_to:)
      return scope if games_from.nil? && games_to.nil?

      if User.games_count_available?
        return apply_games_count_bounds(
          scope,
          comparator: "COALESCE(users.games_count, 0)",
          games_from:,
          games_to:
        )
      end

      apply_games_count_bounds(
        scope.left_joins(:games).group("users.id"),
        comparator: "COUNT(games.id)",
        games_from:,
        games_to:
      )
    end

    def normalize_count_result(result)
      result.is_a?(Hash) ? result.size : result
    end

    # rubocop:enable Metrics/AbcSize
  end
  # rubocop:enable Metrics/ClassLength
end
