# syntax=docker/dockerfile:1

FROM debian:bookworm AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    devscripts \
    debhelper \
    bash \
    sqlite3 \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy the source code
COPY . /build/

# Build the package
RUN dpkg-buildpackage -us -uc

# Export stage - this creates the output files available for extraction
FROM scratch AS output
COPY --from=builder /build/../*.deb /
COPY --from=builder /build/../*.dsc /
COPY --from=builder /build/../*.tar.gz /
COPY --from=builder /build/../*.changes /
