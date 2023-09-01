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
  
  # includes :playlist
  # includes :igdb_cache

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :playlist_id, :igdb_cache_id, :order
  #
  # or
  #
  # permit_params do
  #   permitted = [:name, :user_id]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end

  index do
    id_column
    column :playlist
    column :igdb_cache
    column :order
    column :created_at
    column :updated_at
    actions
  end

  filter :playlist
end
