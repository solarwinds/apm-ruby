ARG RUBY_VERSION
FROM public.ecr.aws/sam/build-ruby${RUBY_VERSION}:latest

ARG RUBY_VERSION
ENV RUBY_VERSION=${RUBY_VERSION}

RUN mkdir /build
COPY . /build

WORKDIR /build/layer
RUN bundle config set --local path 'ruby'

# Save gem filename if present
RUN ls | grep solarwinds_apm-*.gem > gem_file.txt 2>/dev/null || true

# (for local gem only)
RUN gem_file=$(cat gem_file.txt) && \
    if [ -f "$gem_file" ]; then \
        gem install $gem_file; \
        gem unpack $gem_file --target solarwinds_apm/; \
        gem unpack $gem_file --target solarwinds_apm/ --spec; \
        mv solarwinds_apm/*.gemspec solarwinds_apm/solarwinds_apm-*/; \
        LOCAL_GEM_DIR=$(find solarwinds_apm -type d -name "solarwinds_apm-*"); \
        sed -i.bak -E "s|^gem 'solarwinds_apm'.*|gem 'solarwinds_apm', path: '$LOCAL_GEM_DIR'|" Gemfile; \
    fi

# install get gem
RUN bundle install

RUN sh -c '(command -v dnf && dnf install -y wget) || (command -v yum && yum install -y wget)'

ENV ARCH=aarch64
RUN PROTOBUF_VERSION=$(bundle exec ruby -e 'puts Gem.loaded_specs["google-protobuf"].version.to_s') && \
    wget "https://rubygems.org/downloads/google-protobuf-${PROTOBUF_VERSION}-${ARCH}-linux-gnu.gem" && \
    bundle exec gem install "google-protobuf-${PROTOBUF_VERSION}-${ARCH}-linux-gnu.gem"

# (for local gem only)
RUN gem_file=$(cat gem_file.txt) && \
    if [ -f "$gem_file" ]; then \
        rm solarwinds_apm/solarwinds_apm-*/*.gemspec; \
        mv /build/layer/solarwinds_apm/solarwinds_apm-*/ /build/layer/ruby/ruby/${RUBY_VERSION}.0/gems/; \
        mv /var/lang/lib/ruby/gems/${RUBY_VERSION}.0/specifications/solarwinds_apm-* /build/layer/ruby/ruby/${RUBY_VERSION}.0/specifications/; \
    fi

# Clean up cache and docs
RUN rm -rf /build/layer/ruby/ruby/${RUBY_VERSION}.0/cache/* && \
    rm -rf /build/layer/ruby/ruby/${RUBY_VERSION}.0/doc/*

# Zip the layer
WORKDIR /build/layer/ruby/ruby

RUN zip -qr gems-${RUBY_VERSION}.0.zip ${RUBY_VERSION}.0/

CMD cp /build/layer/ruby/ruby/gems-${RUBY_VERSION}.0.zip /out/gems-${RUBY_VERSION}.0.zip
