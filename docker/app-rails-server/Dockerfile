# syntax=docker/dockerfile:1
FROM ruby:2.6.6
RUN apt-get update -y && apt-get install -y apt-file && apt-file update && apt-get install -y nodejs npm ca-certificates docker
RUN sh -c "echo "deb http://apt.postgresql.org/pub/repos/apt/ 'lsb_release -cs'-pgdg main" >> /etc/apt/sources.list.d/pgdg.list" && apt-get update
WORKDIR /app/android-spyware
COPY ./android-spyware /app/android-spyware
RUN gem install bundler:2.1.4 && bundle && npm install yarn -g && yarn install --check-files
ENTRYPOINT rails s -b 0.0.0.0 -p 80
