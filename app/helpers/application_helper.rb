# frozen_string_literal: true

# Application helper
module ApplicationHelper
  def flash_class(level)
    hash = {notice: 'alert-primary', success: 'alert-success', error: 'alert-danger', alert: 'alert-warning'}
    hash[level.to_sym]
  end
end
