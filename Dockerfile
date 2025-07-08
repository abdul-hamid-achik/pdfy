# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is optimized for development

ARG RUBY_VERSION=3.4.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Install base packages including Chrome and dependencies for Grover PDF generation
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    curl \
    git \
    gnupg \
    libpq-dev \
    libjemalloc2 \
    libvips \
    postgresql-client \
    libyaml-dev \
    pkg-config \
    python-is-python3 \
    wget \
    # Dependencies for Chrome/Puppeteer
    libnss3 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    fonts-liberation \
    libappindicator3-1 \
    xdg-utils && \
    # Install Chromium (works on all architectures)
    apt-get install -y chromium chromium-driver && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install Node.js and Yarn
ARG NODE_VERSION=22.14.0
ARG YARN_VERSION=1.22.22
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    npm install -g yarn@$YARN_VERSION && \
    rm -rf /tmp/node-build-master

# Rails app lives here
WORKDIR /rails

# Set development environment
ENV RAILS_ENV="development" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="" \
    CHROME_BIN="/usr/bin/chromium"

# Install gems (do this before copying app code for better caching)
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Install node modules (do this before copying app code for better caching)
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile && \
    yarn cache clean

# Copy application code
COPY . .

# Build assets for production when needed
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile || echo "Asset precompilation skipped"

# Create and own directories
RUN mkdir -p db log storage tmp/pids tmp/cache tmp/sockets public/assets && \
    groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails /rails

USER 1000:1000

# Entrypoint prepares the database
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Expose dynamic port (defaults to 5050)
ARG PORT=5050
ENV PORT=${PORT}
EXPOSE ${PORT}
CMD ["sh", "-c", "./bin/rails server -b 0.0.0.0 -p ${PORT}"]