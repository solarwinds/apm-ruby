# To build one auto-instrumentation image for Ruby, please:
# - Ensure the packages are installed in the `/autoinstrumentation` directory. This is required as when instrumenting the pod,
#   one init container will be created to copy all the content in `/autoinstrumentation` directory to your app's container. Then
#   update the `RUBYOPT` environment variable accordingly. To achieve this, we use multi-stage builds. In the first stage,
#   install all the required packages in one custom directory. Then in the second stage, copy the directory to `/autoinstrumentation`.
# - Grant the necessary access to `/autoinstrumentation` directory. `chmod -R go+r /autoinstrumentation`
# - For auto-instrumentation by container injection, the Linux command cp is
#   used and must be availabe in the image.
FROM ruby:3.3-slim@sha256:2bbd17947b9c898f46aedb91924fff8f4246ba39beaf51a726bad6ddae1d3094 AS build

ARG SOLARWINDS_APM_VERSION

# Install packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends build-essential && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /ruby/build

COPY Gemfile autoinstrumentation.rb ./

RUN bundle config set --local path /ruby/build/vendor && \
    bundle install

RUN mkdir -p /ruby/instrumentation/src && \
    mv vendor/ruby/*/* /ruby/instrumentation/ && \
    cp autoinstrumentation.rb /ruby/instrumentation/src/autoinstrumentation.rb && \
    rm -rf /ruby/instrumentation/cache

FROM busybox@sha256:fd7dc98638c8e305f4dc34e979f1c0fdfdcaeb0fbf8fcff77ae834b6da3d7e6e

# copy all gems from global install to autoinstrumentation
COPY --from=build /ruby/instrumentation/ /autoinstrumentation

RUN chmod -R go+r /autoinstrumentation
