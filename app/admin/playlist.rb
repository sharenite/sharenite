# frozen_string_literal: true

ActiveAdmin.register Playlist do
  config.sort_order = "name"
  menu priority: 4

  belongs_to :user, optional: true
  includes :user

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :name, :user_id, :public
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
    column :user
    column :name
    column :public
    column :created_at
    column :updated_at
    actions
  end

  filter :name, as: :string
end
