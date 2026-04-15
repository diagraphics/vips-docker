FROM --platform=$BUILDPLATFORM curlimages/curl AS fetch
ARG LIBVIPS_VERSION=8.15.3
RUN \
    mkdir -p /tmp/libvips && \
    curl -SL https://github.com/libvips/libvips/archive/refs/tags/v${LIBVIPS_VERSION}.tar.gz | \
    tar -xzC /tmp/libvips

FROM --platform=$BUILDPLATFORM curlimages/curl AS fetch-pdfium
ARG TARGETARCH
ARG PDFIUM_VERSION=6721
RUN \
    PDFIUM_ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "x64") && \
    mkdir -p /tmp/pdfium && \
    curl -SL https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F${PDFIUM_VERSION}/pdfium-linux-${PDFIUM_ARCH}.tgz | \
    tar -xzC /tmp/pdfium

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

# --- PDFium build target ---
# Usage: docker build --target pdfium-final .

FROM base AS build-pdfium
ARG LIBVIPS_VERSION=8.15.3
ARG PDFIUM_VERSION=6721

COPY --from=fetch /tmp /tmp
COPY --from=fetch-pdfium /tmp/pdfium/lib /usr/local/lib
COPY --from=fetch-pdfium /tmp/pdfium/include /usr/local/include

# Generate pkg-config file for PDFium so meson can discover it
RUN mkdir -p /usr/local/lib/pkgconfig && \
    cat > /usr/local/lib/pkgconfig/pdfium.pc <<EOF
prefix=/usr/local
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include
Name: pdfium
Description: pdfium
Version: $PDFIUM_VERSION
Requires:
Libs: -L\${libdir} -lpdfium
Cflags: -I\${includedir}
EOF

WORKDIR /tmp/libvips/libvips-${LIBVIPS_VERSION}
RUN meson setup build && \
    cd build && \
    meson compile && \
    meson test && \
    mkdir -p /tmp/dest && \
    DESTDIR=/tmp/dest meson install

FROM base AS pdfium-final

COPY --from=fetch-pdfium /tmp/pdfium/lib /usr/local/lib
COPY --from=build-pdfium /tmp/dest /
RUN ldconfig

# --- Default build target (poppler) ---

FROM base AS build
ARG LIBVIPS_VERSION=8.15.3

COPY --from=fetch /tmp /tmp
WORKDIR /tmp/libvips/libvips-${LIBVIPS_VERSION}
RUN meson setup build && \
    cd build && \
    meson compile && \
    meson test && \
    mkdir -p /tmp/dest && \
    DESTDIR=/tmp/dest meson install

FROM base AS final

COPY --from=build /tmp/dest /
RUN ldconfig
