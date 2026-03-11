# frozen_string_literal: true

# Friends controller
module Profiles
  # Profiles friends controller
  # rubocop:disable Metrics/ClassLength
  class FriendsController < BaseController
    include ProfileVisibility

    TABS = %w[friends received sent declined blocked].freeze
    SORT_VALUES_BY_TAB = {
      "friends" => %w[last_active_desc last_active_asc friends_since_desc friends_since_asc name_asc name_desc games_desc games_asc],
      "received" => %w[sent_desc sent_asc name_asc name_desc],
      "sent" => %w[sent_desc sent_asc name_asc name_desc],
      "declined" => %w[declined_desc declined_asc name_asc name_desc status_asc status_desc],
      "blocked" => %w[blocked_desc blocked_asc name_asc name_desc]
    }.freeze
    DEFAULT_SORT_BY_TAB = {
      "friends" => "last_active_desc",
      "received" => "sent_desc",
      "sent" => "sent_desc",
      "declined" => "declined_desc",
      "blocked" => "blocked_desc"
    }.freeze
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
      assign_visibility_flags
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

      @friends_total_count = scope.except(:order).count
      @friends = if @active_tab == "friends"
                   ordered_friends_scope(scope).page(params[:page]).per(25).preload(:user)
                 else
                   Profile.none.page(params[:page]).per(25)
                 end
      preload_friend_list_metadata
    end

    def set_invitations
      return reset_invitations unless @own_profile

      filter_options = invitation_filter_options
      return set_unfiltered_invitation_counts if !filter_options[:any_filter] && @active_tab == "friends"

      invitation_collections(filter_options).each do |config|
        assign_invitation_collection(**config)
      end
    end

    def filtered_user_ids_for_invitation_filters(name_query:)
      scope = User.joins(:profile)
                  .select(:id)

      scope = scope.where("profiles.name ILIKE ?", "%#{name_query}%") if name_query.present?
      scope
    end

    def invitation_filter_options
      name_query = params[:search_name].to_s.strip
      any_filter = name_query.present?
      filtered_user_ids = any_filter ? filtered_user_ids_for_invitation_filters(name_query:) : nil

      { any_filter:, filtered_user_ids: }
    end

    def set_unfiltered_invitation_counts
      counts = unfiltered_invitation_counts
      @invitations_received_count = counts.fetch(:received, 0)
      @invitations_sent_count = counts.fetch(:sent, 0)
      @invitations_declined_count = counts.fetch(:declined, 0)
      @blocked_count = counts.fetch(:blocked, 0)
      @invitations_received = []
      @invitations_sent = []
      @invitations_declined = []
      @blocked_relations = []
    end

    def unfiltered_invitation_counts
      user_id = @profile.user.id
      row = Friend.where("inviter_id = :user_id OR invitee_id = :user_id", user_id:)
                  .pick(*unfiltered_invitation_count_expressions(user_id))

      {
        received: row&.[](0).to_i,
        sent: row&.[](1).to_i,
        declined: row&.[](2).to_i,
        blocked: row&.[](3).to_i
      }
    end

    def unfiltered_invitation_count_expressions(user_id)
      quoted_user_id = ActiveRecord::Base.connection.quote(user_id)

      [
        "COALESCE(SUM(CASE WHEN status = 'invited' AND invitee_id = #{quoted_user_id} THEN 1 ELSE 0 END), 0)",
        "COALESCE(SUM(CASE WHEN status = 'invited' AND inviter_id = #{quoted_user_id} THEN 1 ELSE 0 END), 0)",
        "COALESCE(SUM(CASE WHEN status = 'declined' THEN 1 ELSE 0 END), 0)",
        "COALESCE(SUM(CASE WHEN status = 'blocked' AND inviter_id = #{quoted_user_id} THEN 1 ELSE 0 END), 0)"
      ].map { |expression| Arel.sql(expression) }
    end

    def assign_invitation_collection(count_ivar:, records_ivar:, tab_name:, scope:)
      instance_variable_set(count_ivar, scope.count)
      records = @active_tab == tab_name ? sorted_records_for_tab(scope.load, tab_name) : []
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
      return scope unless any_filter

      scope.where(inviter_id: filtered_user_ids)
    end

    def invitation_sent_scope(any_filter:, filtered_user_ids:)
      scope = @profile.user.pending_invitees
                      .includes(invitee: :profile)
      return scope unless any_filter

      scope.where(invitee_id: filtered_user_ids)
    end

    def invitation_declined_scope(any_filter:, filtered_user_ids:)
      scope = Friend.where(status: :declined)
                    .where("inviter_id = :user_id OR invitee_id = :user_id", user_id: @profile.user.id)
                    .includes(inviter: :profile, invitee: :profile)
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
      apply_profile_visibility_scope(Profile.where(user_id: accepted_friend_user_ids_scope))
        .joins(:user)
        .includes(:user)
    end

    def preload_friend_list_metadata
      friend_user_ids = @friends.map(&:user_id)
      @friend_games_count_by_user_id = visible_games_count_by_user_id(@friends)
      @friend_game_library_visibility_by_user_id = component_visibility_by_user_id(@friends, :game_library_privacy)
      @friend_gaming_activity_visibility_by_user_id = component_visibility_by_user_id(@friends, :gaming_activity_privacy)
      @friend_latest_game_activity_at_by_user_id = latest_visible_game_activity_by_user_id_for_profiles(@friends)
      @friend_last_active_at_by_user_id = latest_visible_last_active_by_user_id(
        @friends,
        gaming_activity_visibility_by_user_id: @friend_gaming_activity_visibility_by_user_id,
        latest_game_activity_by_user_id: @friend_latest_game_activity_at_by_user_id
      )
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

    def current_sort
      requested_sort = params[:sort].to_s
      allowed_sorts = sort_values_for_tab(@active_tab)
      allowed_sorts.include?(requested_sort) ? requested_sort : DEFAULT_SORT_BY_TAB.fetch(@active_tab, DEFAULT_SORT_BY_TAB.fetch("friends"))
    end

    def ordered_friends_scope(scope)
      scope.select(
        "profiles.*",
        "#{friend_visible_games_count_sql} AS visible_games_count_for_sort",
        "#{friend_last_active_epoch_sql} AS last_active_epoch_for_sort",
        "#{friendship_updated_at_epoch_sql} AS friendship_updated_at_epoch_for_sort"
      ).order(Arel.sql(friend_order_clause))
    end

    def friend_order_clause
      return friend_games_order_clause if current_sort.start_with?("games_")
      return friend_last_active_order_clause if current_sort.start_with?("last_active_")
      return friend_since_order_clause if current_sort.start_with?("friends_since_")
      return friend_name_order_sql(:desc) if current_sort == "name_desc"

      friend_name_order_sql(:asc)
    end

    def friend_games_order_clause
      direction = current_sort == "games_desc" ? "DESC" : "ASC"
      "#{hidden_component_sort_bucket_sql(:game_library_privacy)} ASC, visible_games_count_for_sort #{direction}, #{friend_name_order_sql(:asc)}"
    end

    def friend_last_active_order_clause
      direction = current_sort == "last_active_desc" ? "DESC" : "ASC"
      "#{hidden_component_sort_bucket_sql(:gaming_activity_privacy)} ASC, last_active_epoch_for_sort #{direction}, #{friend_name_order_sql(:asc)}"
    end

    def friend_since_order_clause
      direction = current_sort == "friends_since_desc" ? "DESC" : "ASC"
      "friendship_updated_at_epoch_for_sort #{direction}, #{friend_name_order_sql(:asc)}"
    end

    def friend_name_order_sql(direction)
      name_direction = direction == :desc ? "DESC" : "ASC"
      "LOWER(COALESCE(profiles.name, '')) #{name_direction}, profiles.user_id ASC"
    end

    def hidden_component_sort_bucket_sql(column)
      "CASE WHEN #{friend_component_visibility_sql(column)} THEN 0 ELSE 1 END"
    end

    def friend_visible_games_count_sql
      <<~SQL.squish
        CASE
          WHEN #{friend_component_visibility_sql(:game_library_privacy)}
          THEN (#{visible_games_count_subquery_sql})
          ELSE 0
        END
      SQL
    end

    def friend_last_active_epoch_sql
      <<~SQL.squish
        CASE
          WHEN #{friend_component_visibility_sql(:gaming_activity_privacy)}
          THEN EXTRACT(EPOCH FROM GREATEST(
            COALESCE(users.last_sign_in_at, TO_TIMESTAMP(0)),
            COALESCE(users.current_sign_in_at, TO_TIMESTAMP(0)),
            COALESCE((#{latest_visible_game_activity_subquery_sql}), TO_TIMESTAMP(0))
          ))
          ELSE 0
        END
      SQL
    end

    def friendship_updated_at_epoch_sql
      "COALESCE(EXTRACT(EPOCH FROM (#{friendship_updated_at_subquery_sql})), 0)"
    end

    def visible_games_count_subquery_sql
      <<~SQL.squish
        SELECT COUNT(*)
        FROM games
        WHERE games.user_id = users.id
          AND (#{game_record_visible_to_viewer_sql})
      SQL
    end

    def latest_visible_game_activity_subquery_sql
      <<~SQL.squish
        SELECT MAX(games.last_activity)
        FROM games
        WHERE games.user_id = users.id
          AND games.last_activity IS NOT NULL
          AND (#{game_record_visible_to_viewer_sql})
      SQL
    end

    def friendship_updated_at_subquery_sql
      user_id = ActiveRecord::Base.connection.quote(@profile.user.id)

      <<~SQL.squish
        SELECT MAX(friends.updated_at)
        FROM friends
        WHERE friends.status = 'accepted'
          AND (
            (friends.inviter_id = #{user_id} AND friends.invitee_id = profiles.user_id)
            OR
            (friends.invitee_id = #{user_id} AND friends.inviter_id = profiles.user_id)
          )
      SQL
    end

    def friend_component_visibility_sql(column)
      privacy_column = "profiles.#{column}"
      return "#{privacy_column} = 'public'" unless current_user

      friend_user_ids_sql = accepted_friend_user_ids_for(current_user.id).to_sql
      viewer_id = ActiveRecord::Base.connection.quote(current_user.id)

      <<~SQL.squish
        profiles.user_id = #{viewer_id}
        OR #{privacy_column} IN ('public', 'members')
        OR (#{privacy_column} = 'friends' AND profiles.user_id IN (#{friend_user_ids_sql}))
      SQL
    end

    def game_record_visible_to_viewer_sql
      return "games.private_override = FALSE" unless current_user

      viewer_id = ActiveRecord::Base.connection.quote(current_user.id)
      "(games.user_id = #{viewer_id} OR games.private_override = FALSE)"
    end

    def sorted_records_for_tab(records, tab_name)
      records.sort_by { |record| sort_value_for_record(record, tab_name) }
    end

    def sort_value_for_record(record, tab_name)
      case tab_name
      when "received"
        received_record_sort_value(record)
      when "sent"
        sent_record_sort_value(record)
      when "declined"
        declined_record_sort_value(record)
      when "blocked"
        blocked_record_sort_value(record)
      else
        [record.id]
      end
    end

    def received_record_sort_value(record)
      invitation_name = safe_profile_name(record.inviter)
      return dated_name_sort_value(record.created_at, invitation_name, record.id, descending: current_sort == "sent_desc") if %w[sent_asc sent_desc].include?(current_sort)
      return descending_name_sort_value(invitation_name, record.id) if current_sort == "name_desc"

      ascending_name_sort_value(invitation_name, record.id)
    end

    def sent_record_sort_value(record)
      invitation_name = safe_profile_name(record.invitee)
      return dated_name_sort_value(record.created_at, invitation_name, record.id, descending: current_sort == "sent_desc") if %w[sent_asc sent_desc].include?(current_sort)
      return descending_name_sort_value(invitation_name, record.id) if current_sort == "name_desc"

      ascending_name_sort_value(invitation_name, record.id)
    end

    def declined_record_sort_value(record)
      other_user = record.inviter_id == @profile.user.id ? record.invitee : record.inviter
      other_name = safe_profile_name(other_user)
      status_label = record.invitee_id == @profile.user.id ? "You declined" : "Declined by them"

      case current_sort
      when "declined_asc", "declined_desc"
        dated_name_sort_value(record.updated_at, other_name, record.id, descending: current_sort == "declined_desc")
      when "status_asc"
        [status_label.downcase, other_name.to_s.downcase, record.id]
      when "status_desc"
        [invert_string_for_desc(status_label.downcase), other_name.to_s.downcase, record.id]
      when "name_desc"
        descending_name_sort_value(other_name, record.id)
      else
        ascending_name_sort_value(other_name, record.id)
      end
    end

    def blocked_record_sort_value(record)
      blocked_name = safe_profile_name(record.invitee)
      return dated_name_sort_value(record.created_at, blocked_name, record.id, descending: current_sort == "blocked_desc") if %w[blocked_asc blocked_desc].include?(current_sort)
      return descending_name_sort_value(blocked_name, record.id) if current_sort == "name_desc"

      ascending_name_sort_value(blocked_name, record.id)
    end

    def dated_name_sort_value(timestamp, name, record_id, descending:)
      [
        privacy_aware_time_sort_value(timestamp, descending:),
        name.to_s.downcase,
        record_id
      ]
    end

    def ascending_name_sort_value(name, record_id)
      [name.to_s.downcase, record_id]
    end

    def descending_name_sort_value(name, record_id)
      [invert_string_for_desc(name.to_s.downcase), record_id]
    end

    def safe_profile_name(user)
      user.profile&.name.presence || "Unknown user"
    end

    def privacy_aware_time_sort_value(value, descending:)
      timestamp = value.to_i
      descending ? -timestamp : timestamp
    end

    def invert_string_for_desc(value)
      value.each_codepoint.map { |codepoint| 0x10FFFF - codepoint }.pack("U*")
    end

    def latest_visible_last_active_by_user_id(profiles, gaming_activity_visibility_by_user_id: nil, latest_game_activity_by_user_id: nil)
      profiles = Array(profiles)
      return {} if profiles.empty?

      gaming_activity_visibility_by_user_id ||= component_visibility_by_user_id(profiles, :gaming_activity_privacy)
      latest_game_activity_by_user_id ||= latest_visible_game_activity_by_user_id_for_profiles(
        profiles,
        gaming_activity_visibility_by_user_id:
      )

      profiles.each_with_object({}) do |profile, result|
        next unless gaming_activity_visibility_by_user_id[profile.user_id]

        latest_auth_activity_at = [profile.user.last_sign_in_at, profile.user.current_sign_in_at].compact.max
        latest_game_activity_at = latest_game_activity_by_user_id[profile.user_id]
        result[profile.user_id] = [latest_auth_activity_at, latest_game_activity_at].compact.max
      end
    end

    def latest_visible_game_activity_by_user_id_for_profiles(profiles, gaming_activity_visibility_by_user_id: nil)
      profiles = Array(profiles)
      return {} if profiles.empty?

      gaming_activity_visibility_by_user_id ||= component_visibility_by_user_id(profiles, :gaming_activity_privacy)
      visible_user_ids = profiles.filter_map { |profile| profile.user_id if gaming_activity_visibility_by_user_id[profile.user_id] }

      latest_visible_game_activity_by_user_id(visible_user_ids)
    end

    def latest_visible_game_activity_by_user_id(user_ids)
      return {} if user_ids.empty?

      scope = Game.where(user_id: user_ids).where.not(last_activity: nil)
      scope = if current_user.present?
                scope.where("games.private_override = FALSE OR games.user_id = ?", current_user.id)
              else
                scope.where(private_override: false)
              end

      scope.group(:user_id).maximum(:last_activity)
    end

    def sort_values_for_tab(tab)
      tab = tab.to_s
      values = SORT_VALUES_BY_TAB.fetch(tab, SORT_VALUES_BY_TAB.fetch("friends"))
      return values if @own_profile || tab != "friends"

      values.reject { |value| value.start_with?("friends_since_") }
    end

    # rubocop:enable Metrics/AbcSize
  end
  # rubocop:enable Metrics/ClassLength
end
