#!/bin/sh
# Starts ccl-server as the unprivileged `ccl` user.
#
# Fresh volumes (Apple container block volumes in particular) are mounted
# root-owned, so fix up /data first, then drop root while keeping only the
# capability needed to listen on ports below 1024 (80/443).
set -eu

if [ "$(id -u)" = 0 ]; then
    chown -R ccl:ccl /data
    exec setpriv --reuid=ccl --regid=ccl --init-groups \
        --inh-caps=-all,+net_bind_service \
        --ambient-caps=-all,+net_bind_service \
        -- /usr/local/bin/ccl-server "$@"
fi

exec /usr/local/bin/ccl-server "$@"
