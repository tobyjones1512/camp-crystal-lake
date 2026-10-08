# Hosting on macOS with Apple container

`ccl-server` ships a `Dockerfile`, so on a Mac you can run it with Apple's
[`container`](https://github.com/apple/container) tool. Each container runs
in its own lightweight Linux VM. You don't need Docker Desktop.

## Requirements

- A Mac with Apple silicon (M1 or newer)
- macOS 26 or newer
- The latest `container` release: grab the signed `.pkg` from the
  [releases page](https://github.com/apple/container/releases)
- A clone of this repository

## Quick start

```sh
git clone https://github.com/CampCrystalLake/ccl-server.git
cd ccl-server
scripts/apple-container.sh start
```

The first `start` does three things: it starts the `container` system service
(on its very first run this offers to download the default Linux kernel),
builds the image, and starts the server in the background. When it's done it
prints the Mac's LAN address. That's the address you give your console as its
DNS server (see the
[hosting guide](https://campcrystallake.xyz/guides/hosting/getting-started/)).

macOS may ask whether to allow incoming network connections. Click **Allow**,
or consoles on your network won't be able to reach the server.

## Day-to-day commands

| Command                                | What it does                                 |
| -------------------------------------- | -------------------------------------------- |
| `scripts/apple-container.sh status`    | Shows the container and your LAN address     |
| `scripts/apple-container.sh logs`      | Follows the server logs (Ctrl+C to stop)     |
| `scripts/apple-container.sh stop`      | Stops the server. Your data is kept          |
| `scripts/apple-container.sh restart`   | Stops, then starts again                     |
| `scripts/apple-container.sh update`    | Rebuilds after a `git pull`, then restarts   |

To pass arguments to `ccl-server` itself, put them after `--`:

```sh
scripts/apple-container.sh start -- --help
```

## Settings

The script reads these environment variables:

| Variable     | Default            | Meaning                                         |
| ------------ | ------------------ | ----------------------------------------------- |
| `CCL_PORTS`  | `9110 9120 9130 9140 9150 3030` | TCP ports forwarded from the Mac into the server |
| `CCL_BIND`   | `0.0.0.0`          | Host address to listen on (`0.0.0.0` = whole LAN) |
| `CCL_VOLUME` | `ccl-server-data`  | Named volume mounted at `/data`                  |
| `CCL_NAME`   | `ccl-server`       | Container name                                   |
| `CCL_IMAGE`  | `ccl-server:latest`| Image tag                                        |

For example, `CCL_BIND=127.0.0.1 scripts/apple-container.sh start` keeps the server reachable from this Mac only.

## Where data lives

Everything the server writes goes to `/data` inside the container. That's
backed by the named volume `ccl-server-data`, so it survives `stop`, `update`
and reboots. To wipe it and start over:

```sh
scripts/apple-container.sh stop
container volume delete ccl-server-data
```

## Without the script

These are the same steps as plain `container` commands:

```sh
container system start
container build --tag ccl-server:latest .
container run --detach --name ccl-server \
  --volume ccl-server-data:/data \
  --publish 0.0.0.0:9110:9110/tcp \
  --publish 0.0.0.0:9120:9120/tcp \
  --publish 0.0.0.0:9130:9130/tcp \
  --publish 0.0.0.0:9140:9140/tcp \
  --publish 0.0.0.0:9150:9150/tcp \
  --publish 0.0.0.0:3030:3030/tcp \
  ccl-server:latest
```

## How it fits together

- The container gets its own private address on the Mac (usually
  `192.168.64.x`). Consoles can't see that address, so the `--publish` rules
  forward the Mac's ports into the container. Always point consoles at the
  **Mac's** LAN address, not the container's.
- The server runs as an unprivileged `ccl` user inside the container, with
  `--data-dir /data` so the database and TLS certificates land in the volume.
- For friends outside your network, forward the same six ports on your router
  to the Mac (see the hosting guide).
- The same `Dockerfile` also works with Docker or Podman on any OS.

## Troubleshooting

- **`container: command not found`**: install the `.pkg` from the releases
  page, then open a new terminal.
- **"address already in use" on start**: something else on the Mac is already
  listening on that port. Find it with `sudo lsof -nP -iTCP:9110 -sTCP:LISTEN`
  (swap in the port from the error).
- **Console can't connect**: check that macOS's firewall lets it through
  (System Settings > Network > Firewall). Also make sure the console and the
  Mac are on the same network, and that the DNS address matches
  `scripts/apple-container.sh status`.
- **Service errors after a macOS update**: run `container system stop`, then
  `container system start`.
