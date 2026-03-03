# frozen_string_literal: true

module ActiveAdminPreserveFiltersOnDestroy
  def smart_collection_url
    return_to = safe_return_to_collection_url
    return return_to if return_to.present?

    referer = request.referer.to_s
    return referer if preserve_filtered_collection_referer?(referer)

    super
  end

  private

  def safe_return_to_collection_url
    raw = params[:return_to].to_s
    return if raw.blank?

    uri = URI.parse(raw)
    return if uri.host.present? && uri.host != request.host
    return unless uri.path == collection_path

    query = uri.query.present? ? "?#{uri.query}" : ""
    "#{uri.path}#{query}"
  rescue URI::InvalidURIError
    nil
  end

  def preserve_filtered_collection_referer?(referer)
    return false if referer.blank?

    uri = URI.parse(referer)
    return false unless uri.path == collection_path
    return false if uri.query.blank?
    return false if uri.host.present? && uri.host != request.host

    true
  rescue URI::InvalidURIError
    false
  end
end

Rails.application.config.to_prepare do
  next unless defined?(ActiveAdmin::ResourceController)

  ActiveAdmin::ResourceController.prepend(ActiveAdminPreserveFiltersOnDestroy)
end
