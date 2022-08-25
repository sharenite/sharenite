#!/bin/sh

set -e

echo "Environment: $RAILS_ENV"

# Check if we need to install new gems and packages
bundle check || bundle install --jobs 20 --retry 5
yarn check || yarn install

# Then run any passed command
bundle exec ${@}