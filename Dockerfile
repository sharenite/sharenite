# syntax = docker/dockerfile:1

ARG RUBY_VERSION=3.3.10
ARG NODE_VERSION=24.21.0
FROM docker.io/library/node:${NODE_VERSION}-bookworm-slim AS node

FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base
ARG RAILS_ENV=production

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips libpq5 postgresql-client procps && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="${RAILS_ENV}" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node /opt/yarn-v1.22.22 /opt/yarn
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx && \
    ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn && \
    ln -s /opt/yarn/bin/yarnpkg /usr/local/bin/yarnpkg && \
    node --version && yarn --version

COPY Gemfile Gemfile.lock ./
RUN --mount=type=secret,id=BUNDLE_GEMS__KARAFKA__IO \
    export BUNDLE_GEMS__KARAFKA__IO="$(cat /run/secrets/BUNDLE_GEMS__KARAFKA__IO)" && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY .node-version package.json yarn.lock ./
RUN test "$(node --version)" = "v$(cat .node-version)" && \
    yarn install --frozen-lockfile

COPY . .

RUN bundle exec bootsnap precompile app/ lib/
RUN --mount=type=secret,id=RAILS_MASTER_KEY \
    export RAILS_MASTER_KEY="$(cat /run/secrets/RAILS_MASTER_KEY)" && \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp

USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
