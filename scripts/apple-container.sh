#!/bin/sh
# Build and run ccl-server on macOS with Apple's `container` tool
# (https://github.com/apple/container).
#
# Usage: scripts/apple-container.sh <command> [-- server args...]
#
# Commands:
#   build     Build the image from the Dockerfile in this repo
#   start     Start the server in the background (builds first if needed)
#   stop      Stop and remove the server container (data is kept)
#   restart   stop, then start
#   update    Rebuild the image and restart the server
#   logs      Follow the server logs
#   status    Show the container and the address to point consoles at
#
# Settings (environment variables):
#   CCL_IMAGE   image tag            (default: ccl-server:latest)
#   CCL_NAME    container name       (default: ccl-server)
#   CCL_VOLUME  data volume name     (default: ccl-server-data)
#   CCL_PORTS   TCP ports to publish (default: "80 443")
#   CCL_BIND    host address to bind (default: 0.0.0.0, i.e. the whole LAN)
set -eu

CCL_IMAGE=${CCL_IMAGE:-ccl-server:latest}
CCL_NAME=${CCL_NAME:-ccl-server}
CCL_VOLUME=${CCL_VOLUME:-ccl-server-data}
CCL_PORTS=${CCL_PORTS:-80 443}
CCL_BIND=${CCL_BIND:-0.0.0.0}

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

preflight() {
    [ "$(uname -s)" = Darwin ] || die "this script is for macOS; use Docker or the native binary elsewhere"
    [ "$(uname -m)" = arm64 ] || die "Apple container requires a Mac with Apple silicon"
    command -v container >/dev/null 2>&1 \
        || die "'container' not found; install it from https://github.com/apple/container/releases"

    if ! container system status >/dev/null 2>&1; then
        echo "Starting the container system service..."
        container system start
    fi
}

image_exists() {
    container image inspect "$CCL_IMAGE" >/dev/null 2>&1
}

container_exists() {
    container list --all --quiet 2>/dev/null | grep -qx "$CCL_NAME"
}

lan_ip() {
    for iface in en0 en1; do
        ip=$(ipconfig getifaddr "$iface" 2>/dev/null || true)
        if [ -n "$ip" ]; then
            echo "$ip"
            return
        fi
    done
}

cmd_build() {
    container build --tag "$CCL_IMAGE" --file "$REPO_ROOT/Dockerfile" "$REPO_ROOT"
}

cmd_start() {
    image_exists || cmd_build
    container_exists && die "'$CCL_NAME' already exists; run '$0 restart' or '$0 stop' first"

    # Named volumes are created on first use and survive stop/update.
    publish=""
    for port in $CCL_PORTS; do
        publish="$publish --publish $CCL_BIND:$port:$port/tcp"
    done

    # shellcheck disable=SC2086 # $publish is a list of flags on purpose
    container run --detach --name "$CCL_NAME" \
        --volume "$CCL_VOLUME:/data" \
        $publish \
        "$CCL_IMAGE" "$@" >/dev/null

    echo "ccl-server is running."
    cmd_status
}

cmd_stop() {
    if container_exists; then
        container stop "$CCL_NAME" >/dev/null 2>&1 || true
        container delete "$CCL_NAME" >/dev/null
        echo "ccl-server stopped (data kept in volume '$CCL_VOLUME')."
    else
        echo "ccl-server is not running."
    fi
}

cmd_status() {
    container list --all | awk -v n="$CCL_NAME" 'NR == 1 || $1 == n'
    ip=$(lan_ip)
    if [ -n "$ip" ]; then
        echo
        echo "Point your console's DNS at this Mac: $ip"
    fi
}

command=${1:-}
[ $# -gt 0 ] && shift
[ "${1:-}" = "--" ] && shift

case "$command" in
    build) preflight && cmd_build ;;
    start) preflight && cmd_start "$@" ;;
    stop) preflight && cmd_stop ;;
    restart) preflight && cmd_stop && cmd_start "$@" ;;
    update) preflight && cmd_build && cmd_stop && cmd_start "$@" ;;
    logs) preflight && container logs --follow "$CCL_NAME" ;;
    status) preflight && cmd_status ;;
    *)
        sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
        [ -z "$command" ] || exit 1
        ;;
esac
