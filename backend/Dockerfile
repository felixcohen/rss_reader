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
RUN useradd -m -s /bin/sh app
WORKDIR /app
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY . .
RUN mkdir -p db && chown -R app:app /app
USER app
EXPOSE 9292
CMD ["bundle", "exec", "puma", "-p", "9292", "config.ru"]
