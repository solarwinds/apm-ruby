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

# Install dependencies
RUN bundle update

# Install wget
RUN sh -c '(command -v dnf && dnf install -y wget) || (command -v yum && yum install -y wget)'

# Install aarch64 version of protobuf gem
ENV ARCH=aarch64
RUN PROTOBUF_VERSION=$(bundle exec ruby -e 'puts Gem.loaded_specs["google-protobuf"].version.to_s') && \
    wget "https://rubygems.org/downloads/google-protobuf-${PROTOBUF_VERSION}-${ARCH}-linux-gnu.gem" && \
    bundle exec gem install "google-protobuf-${PROTOBUF_VERSION}-${ARCH}-linux-gnu.gem"

# Install solarwinds_apm gem (from file, if exists; for local build only)
RUN gem_file=$(cat gem_file.txt) && \
    if [ -f "$gem_file" ]; then \
        gem install $gem_file; \
        bundle exec gem uninstall solarwinds_apm; \
        mv /var/lang/lib/ruby/gems/${RUBY_VERSION}.0/gems/solarwinds_apm-*/ /build/layer/ruby/ruby/${RUBY_VERSION}.0/gems/; \
        mv /var/lang/lib/ruby/gems/${RUBY_VERSION}.0/specifications/solarwinds_apm-* /build/layer/ruby/ruby/${RUBY_VERSION}.0/specifications/; \
    fi

# Clean up cache and docs
RUN rm -rf /build/layer/ruby/ruby/${RUBY_VERSION}.0/cache/* && \
    rm -rf /build/layer/ruby/ruby/${RUBY_VERSION}.0/doc/*

# Zip the layer
WORKDIR /build/layer/ruby/ruby

RUN zip -qr gems-${RUBY_VERSION}.0.zip ${RUBY_VERSION}.0/

CMD cp /build/layer/ruby/ruby/gems-${RUBY_VERSION}.0.zip /out/gems-${RUBY_VERSION}.0.zip
