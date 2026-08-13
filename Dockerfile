# syntax=docker/dockerfile:1

# bump: librabbitmq /LIBRABBITMQ_VERSION=([\d.]+)/ https://github.com/alanxz/rabbitmq-c.git|*
# bump: librabbitmq after ./hashupdate Dockerfile LIBRABBITMQ $LATEST
# bump: librabbitmq link "ChangeLog" https://github.com/alanxz/rabbitmq-c/blob/master/ChangeLog.md
ARG LIBRABBITMQ_VERSION=0.17.0
ARG LIBRABBITMQ_URL="https://github.com/alanxz/rabbitmq-c/archive/refs/tags/v$LIBRABBITMQ_VERSION.tar.gz"
ARG LIBRABBITMQ_SHA256=66c36901178c872565f732468e91688f6280c18810fe8b21a199d46347ba3a0c

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG LIBRABBITMQ_URL
ARG LIBRABBITMQ_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O rabbitmq-c.tar.gz "$LIBRABBITMQ_URL" && \
  echo "$LIBRABBITMQ_SHA256  rabbitmq-c.tar.gz" | sha256sum --status -c - && \
  mkdir rabbitmq-c && \
  tar xf rabbitmq-c.tar.gz -C rabbitmq-c --strip-components=1 && \
  rm rabbitmq-c.tar.gz && \
  apk del download

FROM base AS build
COPY --from=download /tmp/rabbitmq-c/ /tmp/rabbitmq-c/
WORKDIR /tmp/rabbitmq-c/build
RUN \
  apk add --no-cache --virtual build \
    build-base cmake pkgconf \
    openssl-dev openssl-libs-static && \
  cmake \
    -G"Unix Makefiles" \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_STATIC_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTS=OFF \
    -DBUILD_TOOLS=OFF \
    -DBUILD_TOOLS_DOCS=OFF \
    -DRUN_SYSTEM_TESTS=OFF \
    .. && \
  make -j$(nproc) install && \
  pkg-config --exists --modversion --path librabbitmq && \
  ar -t /usr/local/lib/librabbitmq.a && \
  readelf -h /usr/local/lib/librabbitmq.a && \
  apk del build

FROM scratch
ARG LIBRABBITMQ_VERSION
COPY --from=build /usr/local/lib/pkgconfig/librabbitmq.pc /usr/local/lib/pkgconfig/librabbitmq.pc
COPY --from=build /usr/local/lib/librabbitmq.a /usr/local/lib/librabbitmq.a
COPY --from=build /usr/local/include/ /usr/local/include/
