#!/bin/sh
# Starts ccl-server as the unprivileged `ccl` user.
#
# Fresh volumes (Apple container block volumes in particular) are mounted
# root-owned, so fix up /data first, then drop root.
set -eu

if [ "$(id -u)" = 0 ]; then
  chown -R ccl:ccl /data
  exec setpriv --reuid=ccl --regid=ccl --init-groups --inh-caps=-all \
    -- /usr/local/bin/ccl-server "$@"
fi

exec /usr/local/bin/ccl-server "$@"
