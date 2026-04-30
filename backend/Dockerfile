# Stage 1: build gems
FROM ruby:3.2-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y build-essential libsqlite3-dev && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without development:test \
 && bundle install --jobs 4 --retry 3

# Stage 2: runtime
FROM ruby:3.2-slim AS runtime
RUN apt-get update && apt-get install -y libsqlite3-0 curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY . .
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 9292
ENTRYPOINT ["/entrypoint.sh"]
