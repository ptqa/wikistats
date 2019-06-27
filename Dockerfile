FROM ruby:2.5
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -qy update; apt-get install -qy gnuplot
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . /
CMD ["/run.rb"]
