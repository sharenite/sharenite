# frozen_string_literal: true

ActiveAdmin.register Link do
  config.sort_order = "created_at_desc"
  menu parent: "Games", priority: 7

  belongs_to :game, optional: true
  includes :game

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  # permit_params :name, :user_id
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
    column :game
    column :name
    column :url
    column :created_at
    column :updated_at
    actions
  end
end
