# frozen_string_literal: true

# Friends controller
module Profiles
  # Profiles friends controller
  # rubocop:disable Metrics/ClassLength
  class FriendsController < BaseController
    include ProfileVisibility

    TABS = %w[friends received sent declined blocked].freeze
    INVITATION_COLLECTION_CONFIG = [
      {
        count_ivar: :@invitations_received_count,
        records_ivar: :@invitations_received,
        tab_name: "received",
        scope_method: :invitation_received_scope
      },
      {
        count_ivar: :@invitations_sent_count,
        records_ivar: :@invitations_sent,
        tab_name: "sent",
        scope_method: :invitation_sent_scope
      },
      {
        count_ivar: :@invitations_declined_count,
        records_ivar: :@invitations_declined,
        tab_name: "declined",
        scope_method: :invitation_declined_scope
      },
      {
        count_ivar: :@blocked_count,
        records_ivar: :@blocked_relations,
        tab_name: "blocked",
        scope_method: :blocked_scope
      }
    ].freeze

    before_action :check_friends_index_access_profile, only: %i[index]
    before_action :check_current_user_profile, only: %i[accept decline cancel unfriend block unblock]
    before_action :check_friendly_access_profile, only: %i[invite block_profile]

    def index
      @own_profile = profile_own?
      @active_tab = @own_profile ? active_tab : "friends"
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
        when :blocked_by_you
          flash[:error] = "You have blocked this user."
        when :blocked_you
          flash[:error] = "This user is unavailable."
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

    def unfriend
      friend = Friend.find_by(id: params[:id])
      if friend && friend.status_accepted? && friendship_involves_current_user?(friend)
        friend.destroy
        flash[:notice] = "Friend was removed."
      else
        flash[:error] = "Friend relation was not found."
      end
      redirect_to profile_friends_path(current_user.profile, tab: redirect_tab("friends"))
    end

    def block
      friend = Friend.find_by(id: params[:id])
      other_user = friend_other_user(friend)

      if friend && other_user.present? && friendship_involves_current_user?(friend)
        Friend.where(
          "(inviter_id = :current_user_id AND invitee_id = :other_user_id) OR " \
          "(inviter_id = :other_user_id AND invitee_id = :current_user_id)",
          current_user_id: current_user.id,
          other_user_id: other_user.id
        ).delete_all
        Friend.create!(inviter: current_user, invitee: other_user, status: :blocked)
        flash[:notice] = "User was blocked."
      else
        flash[:error] = "Relation was not found."
      end
      redirect_to profile_friends_path(current_user.profile, tab: redirect_tab("blocked"))
    end

    def block_profile
      other_user = @profile.user
      if current_user.id == other_user.id
        flash[:error] = "Can't block yourself."
      else
        Friend.where(
          "(inviter_id = :current_user_id AND invitee_id = :other_user_id) OR " \
          "(inviter_id = :other_user_id AND invitee_id = :current_user_id)",
          current_user_id: current_user.id,
          other_user_id: other_user.id
        ).delete_all
        Friend.create!(inviter: current_user, invitee: other_user, status: :blocked)
        flash[:notice] = "User was blocked."
      end
      redirect_to profile_friends_path(current_user.profile, tab: redirect_tab("blocked"))
    end

    def unblock
      friend = Friend.find_by(id: params[:id])
      if friend && friend.status_blocked? && friend.inviter_id == current_user.id
        friend.destroy
        flash[:notice] = "User was unblocked."
      else
        flash[:error] = "Blocked relation was not found."
      end
      redirect_to profile_friends_path(current_user.profile, tab: redirect_tab("blocked"))
    end
    # rubocop:enable all

    private

    def check_friends_index_access_profile
      set_profile
      return if profile_own?
      return if @profile.visible_to?(current_user) && @profile.friends_list_visible_to?(current_user)

      redirect_to_profiles_with_notice
    rescue ActiveRecord::RecordNotFound
      redirect_to_profiles_with_notice
    end

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
      preload_friend_list_metadata
    end

    def set_invitations
      return reset_invitations unless @own_profile

      filter_options = invitation_filter_options
      invitation_collections(filter_options).each do |config|
        assign_invitation_collection(**config)
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

    def filtered_user_ids_for_invitation_filters(name_query:, games_from:, games_to:)
      scope = User.joins(:profile)
                  .select(:id)

      scope = scope.where("profiles.name ILIKE ?", "%#{name_query}%") if name_query.present?
      apply_user_games_count_filter(scope, games_from:, games_to:)
    end

    def invitation_filter_options
      name_query = params[:search_name].to_s.strip
      games_from = parse_games_count_param(:games_from)
      games_to = parse_games_count_param(:games_to)
      any_filter = name_query.present? || games_from.present? || games_to.present?
      filtered_user_ids = any_filter ? filtered_user_ids_for_invitation_filters(name_query:, games_from:, games_to:) : nil

      { any_filter:, filtered_user_ids: }
    end

    def assign_invitation_collection(count_ivar:, records_ivar:, tab_name:, scope:)
      instance_variable_set(count_ivar, scope.count)
      records = @active_tab == tab_name ? scope.load : []
      instance_variable_set(records_ivar, records)
    end

    def invitation_collections(filter_options)
      INVITATION_COLLECTION_CONFIG.map do |config|
        {
          count_ivar: config[:count_ivar],
          records_ivar: config[:records_ivar],
          tab_name: config[:tab_name],
          scope: send(config[:scope_method], **filter_options)
        }
      end
    end

    def reset_invitations
      @invitations_received_count = 0
      @invitations_received = []
      @invitations_sent_count = 0
      @invitations_sent = []
      @invitations_declined_count = 0
      @invitations_declined = []
      @blocked_count = 0
      @blocked_relations = []
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

    def blocked_scope(any_filter:, filtered_user_ids:)
      scope = Friend.where(status: :blocked, inviter_id: @profile.user.id)
                    .includes(invitee: :profile)
                    .order(updated_at: :desc)
      return scope unless any_filter

      scope.where(invitee_id: filtered_user_ids)
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
      scope = apply_profile_visibility_scope(Profile.where(user_id: accepted_friend_user_ids_scope))
              .joins(:user)
              .joins("LEFT JOIN games AS visible_games ON visible_games.user_id = users.id AND visible_games.private_override = FALSE")
      scope.select("profiles.*, COUNT(visible_games.id) AS games_count")
           .group("profiles.id")
    end

    def apply_games_count_filter(scope, games_from:, games_to:)
      return scope if games_from.nil? && games_to.nil?

      apply_games_count_bounds(scope, comparator: "COUNT(visible_games.id)", games_from:, games_to:)
    end

    def apply_games_count_bounds(scope, comparator:, games_from:, games_to:)
      scope = scope.having("#{comparator} >= ?", games_from) unless games_from.nil?
      return scope.having("#{comparator} <= ?", games_to) unless games_to.nil?

      scope
    end

    def apply_user_games_count_filter(scope, games_from:, games_to:)
      return scope if games_from.nil? && games_to.nil?

      apply_games_count_bounds(
        scope.joins("LEFT JOIN games AS visible_games ON visible_games.user_id = users.id AND visible_games.private_override = FALSE")
             .group("users.id"),
        comparator: "COUNT(visible_games.id)",
        games_from:,
        games_to:
      )
    end

    def normalize_count_result(result)
      result.is_a?(Hash) ? result.size : result
    end

    def preload_friend_list_metadata
      friend_user_ids = @friends.map(&:user_id)
      @friend_games_count_by_user_id = visible_games_count_by_user_id(@friends)
      @friend_game_library_visibility_by_user_id = component_visibility_by_user_id(@friends, :game_library_privacy)
      @friend_relations_by_user_id = if @own_profile && friend_user_ids.any?
                                       accepted_friend_relations_by_user_id(friend_user_ids)
                                     else
                                       {}
                                     end
    end

    def accepted_friend_relations_by_user_id(friend_user_ids)
      Friend.where(status: :accepted)
            .where("inviter_id = :user_id OR invitee_id = :user_id", user_id: @profile.user.id)
            .where("inviter_id IN (:friend_user_ids) OR invitee_id IN (:friend_user_ids)", friend_user_ids:)
            .index_by do |relation|
              relation.inviter_id == @profile.user.id ? relation.invitee_id : relation.inviter_id
            end
    end

    def friendship_involves_current_user?(friend)
      friend.inviter_id == current_user.id || friend.invitee_id == current_user.id
    end

    def friend_other_user(friend)
      return unless friend

      friend.inviter_id == current_user.id ? friend.invitee : friend.inviter
    end

    # rubocop:enable Metrics/AbcSize
  end
  # rubocop:enable Metrics/ClassLength
end
