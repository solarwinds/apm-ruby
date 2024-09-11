# Dockerfile
# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

FROM ubuntu:22.04

ARG BUNDLE_RUBYGEMS__PKG__GITHUB__COM

ENV TZ=America/Vancouver
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV SW_APM_REPORTER=file

# install OS packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       apt-utils \
       autoconf \
       autotools-dev \
       automake \
       bash \
       bison \
       build-essential \
       cmake \
       curl \
       gdb \
       git-core \
       less \
       libcurl4-gnutls-dev \
       default-libmysqlclient-dev \
       libpq-dev \
       libpcre3-dev \
       libreadline-dev \
       libsasl2-dev \
       libsqlite3-dev \
       libssl-dev \
       libyaml-dev \
       pkg-config \
       psmisc \
       ruby \
       tcl \
       tmux \
       tree \
       vim \
       zlib1g-dev \
       shared-mime-info \
    && rm -rf /var/lib/apt/lists/*

# rbenv setup
# use rbenv-default-gems to automatically install bundler for each ruby version
RUN  git clone https://github.com/rbenv/rbenv.git ~/.rbenv \
     && git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build \
     && git clone https://github.com/rbenv/rbenv-default-gems.git ~/.rbenv/plugins/rbenv-default-gems \
     && echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.profile \
     && echo 'eval "$(rbenv init -)"' >> ~/.profile \
     && echo 'eval "$(rbenv init -)"' >> ~/.bashrc \
     && echo 'bundler' > ~/.rbenv/default-gems

RUN echo 'alias be="bundle exec"' >> ~/.bashrc
RUN echo 'alias be="bundle exec"' >> ~/.profile

# install rubies to build our gem against
RUN . ~/.profile \
    && cd /root/.rbenv/plugins/ruby-build && git pull && cd - \
    && rbenv install 3.1.0

RUN echo 'gem: --no-document' >> ~/.gemrc

# install swig 4.0.2
RUN curl -SL https://github.com/swig/swig/archive/refs/tags/v4.0.2.tar.gz \
    | tar xzC /tmp \
    && cd /tmp/swig-4.0.2 \
    && ./autogen.sh \
    && ./configure && make && make install \
    && cd - \
    && rm -rf /tmp/swig-4.0.2

# set up github package credentials for pushing
RUN mkdir ~/.gem \
    && echo "---\n:github: Bearer ${BUNDLE_RUBYGEMS__PKG__GITHUB__COM}" >> ~/.gem/credentials \
    && chmod 0600 ~/.gem/credentials

ENV PATH="/usr/local/bin:/root/.rbenv/bin:/root/.rbenv/shims:$PATH"

CMD /bin/bash
