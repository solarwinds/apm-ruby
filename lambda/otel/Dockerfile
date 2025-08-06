ARG RUBY_VERSION
FROM public.ecr.aws/sam/build-ruby${RUBY_VERSION}:latest

ARG RUBY_VERSION
ENV RUBY_VERSION=${RUBY_VERSION}

WORKDIR /build/layer
COPY . /build
RUN mkdir -p ruby/ruby/${RUBY_VERSION}.0

# Save gem filename if present
RUN ls | grep solarwinds_apm-*.gem > gem_file.txt 2>/dev/null || true

RUN gem_file=$(ls | grep solarwinds_apm-*.gem 2>/dev/null || true) && \
    gem install ${gem_file:-solarwinds_apm} --install-dir ruby/ruby/${RUBY_VERSION}.0 --no-document

# Clean up cache and docs
RUN rm -rf /build/layer/ruby/ruby/${RUBY_VERSION}.0/cache/* && \
    rm -rf /build/layer/ruby/ruby/${RUBY_VERSION}.0/doc/*

# Zip the layer
WORKDIR /build/layer/ruby/ruby

RUN zip -qr gems-${RUBY_VERSION}.0.zip ${RUBY_VERSION}.0/

CMD cp /build/layer/ruby/ruby/gems-${RUBY_VERSION}.0.zip /out/gems-${RUBY_VERSION}.0.zip
