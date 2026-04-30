#!/bin/sh
set -e
mkdir -p /data
bundle exec rake db:migrate
exec bundle exec puma -p 9292 config.ru
