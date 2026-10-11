# frozen_string_literal: true

module API
  # Uses the application's serializers without depending on Grape's routing internals.
  module JsonFormatter
    def self.call(resource, env)
      ActiveModelSerializers::SerializableResource.new(resource, scope: env["api.endpoint"]).to_json
    end
  end
end
