# syntax=docker/dockerfile:1
#
# OCI image for ccl-server. Builds with Apple `container build` on macOS
# (see docs/apple-container.md) as well as with Docker or Podman.

ARG RUST_IMAGE=rust:1-slim-bookworm
ARG RUNTIME_IMAGE=debian:bookworm-slim

FROM ${RUST_IMAGE} AS build
WORKDIR /src

# Install the toolchain pinned in rust-toolchain.toml in its own layer.
COPY rust-toolchain.toml ./
RUN rustup toolchain install --profile minimal

# Build dependencies against a stub main so they stay cached between source edits.
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo 'fn main() {}' > src/main.rs \
    && cargo build --release --locked \
    && rm -rf src target/release/ccl-server target/release/deps/ccl_server-* \
        target/release/.fingerprint/ccl-server-*

COPY src ./src
# COPY keeps the original mtimes, which can look older than the stub build.
RUN touch src/main.rs && cargo build --release --locked

FROM ${RUNTIME_IMAGE}
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 --user-group --home-dir /data --no-create-home ccl \
    && mkdir -p /data \
    && chown ccl:ccl /data

COPY --from=build /src/target/release/ccl-server /usr/local/bin/ccl-server
COPY scripts/container-entrypoint.sh /usr/local/bin/container-entrypoint.sh

WORKDIR /data
VOLUME ["/data"]
EXPOSE 80/tcp 443/tcp

ENTRYPOINT ["/usr/local/bin/container-entrypoint.sh"]
