#!/bin/sh

set -e

echo "Environment: $RAILS_ENV"

# Check if we need to install new gems and packages
bundle check || bundle install --jobs 20 --retry 5
yarn check || yarn install
bundle exec rake assets:precompile
bundle exec rake assets:clean
bundle exec rake db:migrate
bundle exec karafka topics migrate	
bundle exec rake appsignal:update_version

# Remove pre-existing puma/passenger server.pid
rm -f $APP_PATH/tmp/pids/server.pid

# run passed commands
bundle exec ${@}