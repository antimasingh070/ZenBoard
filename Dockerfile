FROM ruby:3.2.2-slim

# Dependencies इंस्टॉल करें
RUN apt-get update -qq && \
    apt-get install -y build-essential libpq-dev nodejs git

WORKDIR /app

# Bundler वर्जन फिक्स करें
RUN gem install bundler -v 2.6.6

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD ["rails", "server", "-b", "0.0.0.0"]