# frozen_string_literal: true

ActiveAdmin.register PlaylistItem do
  config.sort_order = 'playlist_id_asc'
  menu parent: "Playlists", priority: 1

  order_by(:playlist_id) do |order_clause|
    fields = [:playlist_id, :order]

    fields.map do |field|
      PlaylistItem.arel_table[field].public_send(order_clause.order)
    end.map(&:to_sql).join(', ')
  end
  
  includes :igdb_cache, playlist: { user: :profile }

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :playlist_id, :igdb_cache_id, :igdb_id, :order
  #
  # or
  #
  # permit_params do
  #   permitted = [:name, :user_id]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end

  collection_action :playlist_options, method: :get do
    query = params[:q].to_s.strip
    playlists = Playlist.includes(:user).order(:name)
    if query.present?
      sanitized_query = ActiveRecord::Base.sanitize_sql_like(query)
      playlists = playlists.joins(:user).where("playlists.name ILIKE :q OR users.email ILIKE :q", q: "%#{sanitized_query}%")
    else
      playlists = playlists.none
    end

    render json: playlists.limit(20).map { |playlist| { id: playlist.id, label: playlist_autocomplete_label(playlist) } }
  end

  collection_action :igdb_lookup, method: :get do
    igdb_id = params[:q].to_s.strip
    igdb_cache = IgdbCache.get_by_igdb_id(igdb_id)
    if igdb_cache
      render json: { id: igdb_cache.id, igdb_id: igdb_cache.igdb_id, label: igdb_cache.name }
    else
      render json: {}
    end
  end

  controller do
    before_action :prepare_playlist_item_position, only: %i[create update]

    def create
      @playlist_item = PlaylistItem.new
      assign_playlist_item_attributes!(@playlist_item, creating: true)
      return render :new, status: :unprocessable_entity if @playlist_item.errors.any?

      if @playlist_item.save
        apply_playlist_item_position!(@playlist_item)
        redirect_to resource_path(@playlist_item), notice: "Playlist item was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotUnique
      @playlist_item.errors.add(:base, "IGDB ID is already added to this playlist.")
      render :new, status: :unprocessable_entity
    end

    def update
      @playlist_item = resource
      previous_playlist_id = @playlist_item.playlist_id
      assign_playlist_item_attributes!(@playlist_item, creating: false)
      return render :edit, status: :unprocessable_entity if @playlist_item.errors.any?

      if @playlist_item.save
        apply_playlist_item_position!(@playlist_item)
        PlaylistItem.normalize_for_playlist_id!(previous_playlist_id) if previous_playlist_id != @playlist_item.playlist_id
        redirect_to resource_path(@playlist_item), notice: "Playlist item was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotUnique
      @playlist_item.errors.add(:base, "IGDB ID is already added to this playlist.")
      render :edit, status: :unprocessable_entity
    end

    private

    def build_new_resource
      resource = super
      return resource if resource.playlist_id.present?

      playlist_id = playlist_id_from_context
      return resource if playlist_id.blank?

      playlist = Playlist.find_by(id: playlist_id)
      resource.playlist = playlist if playlist
      resource
    end

    def playlist_id_from_context
      direct = params[:playlist_id].presence ||
               params.dig(:playlist_item, :playlist_id).presence ||
               params.dig(:playlist_item, "playlist_id").presence ||
               params.dig(:q, :playlist_id_eq).presence ||
               params.dig(:q, "playlist_id_eq").presence
      return direct if direct.present?

      referer = request.referer.to_s
      return if referer.blank?

      uri = URI.parse(referer)
      referer_params = Rack::Utils.parse_nested_query(uri.query.to_s)
      referer_params.dig("q", "playlist_id_eq").presence
    rescue URI::InvalidURIError
      nil
    end

    def playlist_autocomplete_label(playlist)
      "#{playlist.name} (#{playlist.user&.email || "no-owner"})"
    end

    def playlist_item_params_for_admin
      params.require(:playlist_item).permit(:playlist_id, :igdb_cache_id, :igdb_id, :playlist_query, :order)
    end

    def prepare_playlist_item_position
      @desired_position = parse_position(playlist_item_params_for_admin[:order])
    end

    def parse_position(value)
      parsed = Integer(value, 10)
      parsed.positive? ? parsed : nil
    rescue ArgumentError, TypeError
      nil
    end

    def assign_playlist_item_attributes!(record, creating:)
      attrs = playlist_item_params_for_admin
      target_playlist = resolve_target_playlist(attrs, record)
      target_igdb_cache = resolve_target_igdb_cache(attrs, record)

      unless target_playlist
        record.errors.add(:playlist, "must exist")
        return
      end

      unless target_igdb_cache
        add_igdb_errors(record, attrs)
        return
      end

      duplicate_scope = target_playlist.playlist_items.where(igdb_cache_id: target_igdb_cache.id)
      duplicate_scope = duplicate_scope.where.not(id: record.id) unless creating
      if duplicate_scope.exists?
        record.errors.add(:base, "IGDB ID is already added to this playlist.")
        return
      end

      new_order = if creating || target_playlist.id != record.playlist_id
                    (target_playlist.playlist_items.where.not(id: record.id).maximum(:order) || 0) + 1
                  else
                    record.order
                  end

      record.assign_attributes(
        playlist: target_playlist,
        igdb_cache: target_igdb_cache,
        order: new_order
      )
    end

    def apply_playlist_item_position!(record)
      return if @desired_position.nil?

      PlaylistItem.move_to_position!(record.playlist, record.id, @desired_position)
    end

    def resolve_target_playlist(attrs, record)
      playlist_id = attrs[:playlist_id].presence || record.playlist_id
      return Playlist.find_by(id: playlist_id) if playlist_id.present?

      playlist_query = attrs[:playlist_query].to_s.strip
      return if playlist_query.blank?

      exact = Playlist.find_by(name: playlist_query)
      return exact if exact

      Playlist.find_by(name: playlist_query.sub(/\s+\([^)]+\)\z/, ""))
    end

    def resolve_target_igdb_cache(attrs, record)
      has_igdb_param = attrs.key?(:igdb_id) || attrs.key?("igdb_id")
      igdb_id = attrs[:igdb_id].to_s.strip
      return IgdbCache.get_by_igdb_id(igdb_id) if igdb_id.present?
      return if has_igdb_param

      igdb_cache_id = attrs[:igdb_cache_id].presence || record.igdb_cache_id
      IgdbCache.find_by(id: igdb_cache_id)
    end

    def add_igdb_errors(record, attrs)
      igdb_id = attrs[:igdb_id].to_s.strip
      if igdb_id.blank?
        record.errors.add(:base, "IGDB ID must exist.")
      else
        record.errors.add(:base, "IGDB ID not found.")
      end
    end
  end

  index do
    id_column
    column :playlist
    column("Owner email") { |item| item.playlist.user&.email }
    column("Owner username") { |item| item.playlist.user&.profile&.name.presence || "-" }
    column :igdb_cache
    column :order
    column :created_at
    column :updated_at
    actions
  end

  filter :playlist
  filter :playlist_name, as: :string
  filter :playlist_user_email, as: :string
  filter :playlist_user_profile_name, as: :string

  form do |f|
    selected_playlist = f.object.playlist
    selected_playlist_label = if selected_playlist
                                "#{selected_playlist.name} (#{selected_playlist.user&.email || "no-owner"})"
                              else
                                params.dig(:playlist_item, :playlist_query).to_s
                              end
    f.object.playlist_query = selected_playlist_label

    selected_igdb = f.object.igdb_cache
    selected_igdb_id = params.dig(:playlist_item, :igdb_id).presence || selected_igdb&.igdb_id
    selected_igdb_name = selected_igdb&.name.to_s
    f.object.igdb_id = selected_igdb_id
    f.object.igdb_name_preview = selected_igdb_name

    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs do
      f.input :playlist_query,
              label: "Playlist",
              input_html: {
                id: "playlist-item-playlist-query",
                placeholder: "Type to search playlists",
                autocomplete: "off",
                data: {
                  autocomplete_url: playlist_options_admin_playlist_items_path,
                  hidden_id_target: "playlist-item-playlist-id",
                  autocomplete_menu_class: "admin-filter-autocomplete-menu",
                  autocomplete_item_class: "admin-filter-autocomplete-item"
                }
              }
      f.input :playlist_id, as: :hidden, input_html: { id: "playlist-item-playlist-id" }

      f.input :igdb_id,
              label: "IGDB ID",
              as: :number,
              input_html: {
                id: "playlist-item-igdb-id",
                min: 1,
                placeholder: "Enter IGDB ID",
                autocomplete: "off",
                data: {
                  igdb_lookup_url: igdb_lookup_admin_playlist_items_path,
                  igdb_name_target: "playlist-item-igdb-name",
                  igdb_cache_id_target: "playlist-item-igdb-cache-id"
                }
              }
      f.input :igdb_cache_id, as: :hidden, input_html: { id: "playlist-item-igdb-cache-id" }

      f.input :igdb_name_preview, label: "IGDB name", input_html: { id: "playlist-item-igdb-name", readonly: true }

      f.input :order, input_html: { min: 1 }
    end
    f.actions
  end

  sidebar "Playlist Links", only: %i[show edit] do
    ul do
      if resource.playlist.present?
        li link_to("Playlist", admin_playlist_path(resource.playlist))
        li link_to("Playlist items", admin_playlist_items_path(q: { playlist_id_eq: resource.playlist_id }))
      end
    end
  end
end
