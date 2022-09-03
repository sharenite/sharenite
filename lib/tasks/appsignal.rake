# frozen_string_literal: true
namespace :appsignal do
  desc "TODO"
  task update_version: :environment do
    require "yaml"
    data = YAML.load_file "config/appsignal.yml"
    `git config --global --add safe.directory /var/app`
    data["production"]["revision"] = `git rev-parse --short HEAD`.strip
    File.open("./config/appsignal.yml", "w") { |f| YAML.dump(data, f) }
  end
end
