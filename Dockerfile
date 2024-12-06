FROM curlimages/curl AS fetch
RUN \
    mkdir -p /tmp/libvips && \
    curl -SL https://github.com/libvips/libvips/archive/refs/tags/v8.15.3.tar.gz | \
    tar -xzC /tmp/libvips

FROM node:18.20.5-bookworm-slim AS base

RUN apt-get update && apt-get install -y \
    build-essential \
    ninja-build \
    python3-pip \
    bc \
    wget \
    meson \
    pkg-config \
    cmake \
    libglib2.0-dev \
    libgirepository1.0-dev \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    libfftw3-dev \
    libopenexr-dev \
    libgsf-1-dev \
    libglib2.0-dev \
    liborc-dev \
    libopenslide-dev \
    libmatio-dev \
    libwebp-dev \
    # libjpeg-turbo8-dev \
    libexpat1-dev \
    libexif-dev \
    libtiff5-dev \
    libcfitsio-dev \
    libpoppler-glib-dev \
    librsvg2-dev \
    libpango1.0-dev \
    libopenjp2-7-dev \
    libimagequant-dev

FROM base AS build

COPY --from=fetch /tmp /tmp
WORKDIR /tmp/libvips/libvips-8.15.3

RUN \
    meson setup build && \
    cd build && \
    meson compile && \
    meson test && \
    mkdir -p /tmp/dest && \
    DESTDIR=/tmp/dest meson install

FROM base AS final

COPY --from=build /tmp/dest /
RUN ldconfig
