#!/bin/sh

set -e

echo "Environment: $RAILS_ENV"

# Check if we need to install new gems and packages
bundle check || bundle install --jobs 20 --retry 5
yarn check || yarn install
rake assets:precompile
rake assets:clean
rake db:migrate
bundle exec karafka-web migrate
rake appsignal:update_version

# Remove pre-existing puma/passenger server.pid
rm -f $APP_PATH/tmp/pids/server.pid

# run passed commands
bundle exec ${@}