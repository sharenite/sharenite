# frozen_string_literal: true

module Admin
  # Provides lightweight autocomplete suggestions for ActiveAdmin filter fields.
  class FilterAutocompleteController < ApplicationController
    MAX_RESULTS = 12
    skip_before_action :authenticate_user!
    before_action :authenticate_admin_user!

    def index
      resource_key = params[:resource].to_s
      attribute = params[:attribute].to_s
      query = params[:q].to_s.strip
      return render json: [] if query.length < 2

      admin_resource = find_admin_resource(resource_key)
      return render json: [] unless admin_resource

      suggestions = autocomplete_values(admin_resource.resource_class, attribute, query)
      render json: suggestions.map { |value| { label: value } }
    end

    private

    def find_admin_resource(resource_key)
      ActiveAdmin.application.namespaces[:admin].resources.find do |resource|
        resource.resource_name.route_key == resource_key
      end
    end

    def autocomplete_values(model, attribute, query)
      return [] if attribute.blank?

      if model.column_names.include?(attribute)
        return direct_column_values(model, attribute, query)
      end

      if (email_match = attribute.match(/\A(.+)_email\z/))
        return association_column_values(model, email_match[1], "email", query)
      end

      if (name_match = attribute.match(/\A(.+)_name\z/))
        return association_column_values(model, name_match[1], "name", query)
      end

      []
    end

    def direct_column_values(model, column_name, query)
      sanitized_query = ActiveRecord::Base.sanitize_sql_like(query)
      model.where("#{model.table_name}.#{column_name} ILIKE ?", "%#{sanitized_query}%")
           .where.not(column_name => [nil, ""])
           .distinct
           .order(column_name => :asc)
           .limit(MAX_RESULTS)
           .pluck(column_name)
    end

    def association_column_values(model, association_path, column_name, query)
      associations, association_model = resolve_association_path(model, association_path)
      return [] if associations.blank? || association_model.nil?
      return [] unless association_model.column_names.include?(column_name)

      table_name = association_model.table_name
      sanitized_query = ActiveRecord::Base.sanitize_sql_like(query)

      model.joins(build_joins_argument(associations))
           .where("#{table_name}.#{column_name} ILIKE ?", "%#{sanitized_query}%")
           .where.not(table_name => { column_name => [nil, ""] })
           .distinct
           .order("#{table_name}.#{column_name} ASC")
           .limit(MAX_RESULTS)
           .pluck("#{table_name}.#{column_name}")
    end

    def resolve_association_path(model, association_path)
      parts = association_path.to_s.split("_")
      associations = []
      current_model = model
      index = 0

      while index < parts.length
        match = longest_association_match(current_model, parts, index)
        return [[], nil] if match.nil?

        associations << match[:name]
        current_model = match[:reflection].klass
        index = match[:next_index]
      end

      [associations, current_model]
    end

    def longest_association_match(model, parts, start_index)
      (parts.length - 1).downto(start_index).each do |end_index|
        candidate = parts[start_index..end_index].join("_")
        reflection = model.reflect_on_association(candidate.to_sym)
        next unless reflection

        return {
          name: candidate.to_sym,
          reflection:,
          next_index: end_index + 1
        }
      end
      nil
    end

    def build_joins_argument(associations)
      return associations.first if associations.length == 1

      associations.reverse.reduce do |memo, association|
        { association => memo }
      end
    end
  end
end
