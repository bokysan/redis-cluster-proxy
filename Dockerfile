ARG BASE_IMAGE=debian:latest

# ================================================================= #
FROM --platform=$TARGETPLATFORM $BASE_IMAGE as base
ARG TARGETPLATFORM

RUN --mount=type=cache,id=var-cache-apk-$TARGETPLATFORM,target=/var/cache/apk,sharing=locked \
    --mount=type=cache,id=etc-apk-cache-$TARGETPLATFORM,target=/etc/apk/cache,sharing=locked \
    --mount=type=cache,id=var-cache-apt-$TARGETPLATFORM,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=var-lib-apt-$TARGETPLATFORM,target=/var/lib/apt,sharing=locked \
    env DEBIAN_FRONTEND=noninteractive apt-get -y update && \
    env DEBIAN_FRONTEND=noninteractive apt-get -y install strace python3 redis && \
    groupadd -g 6379 redis-proxy && \
    useradd -m -d /home/redis-proxy --non-unique --uid 6379 --gid 6379 redis-proxy

# ================================================================= #
FROM --platform=$BUILDPLATFORM alpine:latest as pull
ARG BUILDPLATFORM
RUN apk add git patch && \
    addgroup -g 6379 redis-proxy && \
    adduser -G redis-proxy -D -h /tmp -u 6379 redis-proxy

COPY *.patch /tmp
WORKDIR /tmp
USER redis-proxy
RUN git clone --depth 1 --branch 1.0-beta2 https://github.com/RedisLabs/redis-cluster-proxy.git
RUN cd redis-cluster-proxy && patch --strip 1 -i ../issue-#109.patch

# ================================================================= #
FROM --platform=$TARGETPLATFORM base AS build
ARG TARGETPLATFORM

RUN --mount=type=cache,id=var-cache-apk-$TARGETPLATFORM,target=/var/cache/apk,sharing=locked \
    --mount=type=cache,id=etc-apk-cache-$TARGETPLATFORM,target=/etc/apk/cache,sharing=locked \
    --mount=type=cache,id=var-cache-apt-$TARGETPLATFORM,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=var-lib-apt-$TARGETPLATFORM,target=/var/lib/apt,sharing=locked \
    env DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential git

COPY --link --from=pull /tmp/redis-cluster-proxy/ /tmp/redis-cluster-proxy/
WORKDIR /tmp/redis-cluster-proxy

USER redis-proxy
RUN git config --add safe.directory /tmp/redis-cluster-proxy
RUN make

USER root
RUN make install

# ================================================================= #
FROM --platform=$TARGETPLATFORM base
ARG TARGETPLATFORM

COPY --link --from=build /usr/local/bin/redis-cluster-proxy /usr/local/bin/redis-cluster-proxy
RUN <<EOF
set -e
set -x
chmod +x /usr/local/bin/redis-cluster-proxy
ldd /usr/local/bin/redis-cluster-proxy
mkdir -p /usr/local/etc/redis-cluster-proxy
mkdir -p /usr/local/run/redis-cluster-proxy
EOF

VOLUME /usr/local/etc/redis-cluster-proxy
VOLUME /usr/local/run/redis-cluster-proxy

# Now run in usermode
USER redis-proxy
WORKDIR /home/redis-proxy

ENTRYPOINT ["/usr/local/bin/redis-cluster-proxy"]
EXPOSE 6379

