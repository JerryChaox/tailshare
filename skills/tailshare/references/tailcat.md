# Tailcat reference

Checked against tailcat v0.7.0, the latest release (Nov 2026).
`tailcat <cmd> --help` is the source of truth; rerun it if a flag below is
rejected.

## Install

| Platform | Command |
|---|---|
| macOS | `brew install tailcat` |
| Windows | `scoop install tailcat` |
| Linux | `sudo snap install tailcat`, or .deb/.rpm/tar.gz from github.com/tailscale/tailcat/releases |
| Container | `docker run --rm -i ghcr.io/tailscale/tailcat:latest` |

## How a connection is made

- `serve` generates (or loads) a WireGuard key, picks a DERP relay region,
  connects out to it and prints a `tc...` address. Nothing is registered
  anywhere; the address is computed locally.
- The address encodes the server's public key, the relay region (or full
  relay info with `--full-address`) and, by default, a pre-shared key.
- A client reads the address, meets the server at that relay, does the
  WireGuard handshake, then tries NAT traversal for a direct path. The relay
  only forwards encrypted packets. Default relays are Tailscale's free,
  rate-limited ones (`https://tailcat.dev/derpmap.json`); you can run your own.

## Keys

```sh
tailcat genkey --key=default --fixed-region       # server key; serve loads it automatically
tailcat genkey --key=default --region=<id|code>    # pin a region (see --region=list)
tailcat genkey --client --key=client-default      # client identity; prints nodekey:...
tailcat genkey --list
```

- Without a saved server key, every `serve` gets a new address.
- With a saved key but `--region=auto` (the default), the region is re-picked
  by latency at each start, so the address can still change. `--fixed-region`
  bakes it in.
- Keys live in `$CONFIG/tailcat/keys/<name>.private.json` (macOS:
  `~/Library/Application Support/tailcat/keys/`). The client's `nodekey:...`
  is public; the JSON file is the secret.

## Serving

```sh
tailcat serve 3000                                 # guest's port 3000 → local 3000
tailcat serve 22,80,8000-8010                      # same ports on localhost
tailcat serve --allow=nodekey:A,nodekey:B 3000
tailcat serve --ssh-authorized-keys=alice@github ssh
tailcat serve --ssh-authorized-keys="$HOME/.ssh/authorized_keys" ssh
tailcat serve --allow=nodekey:A no-auth-ssh        # $TAILCAT_PEER_KEY in the session
tailcat serve --ssh-authorized-keys=alice@github ssh -- ./task.sh   # forced command
tailcat serve --files=/pub:ro files                # scp/sftp; :rw, :wo, :wo+ also exist
TAILCAT_ADDR_FILE=/tmp/addr tailcat serve 80       # also write the address to a file
```

- Flags go before the port/service list.
- Ports always map to the same port on localhost in v0.7.0.
  `80:127.0.0.1:3000`-style mappings exist only on tailcat's main branch,
  after v0.7.0; a released binary rejects them as an unknown service.
- `--allow` gates the tunnel itself: unlisted keys never complete a
  connection. It's read once at startup.
- `ssh` checks SSH public keys; `alice@github` fetches
  `https://github.com/alice.keys` at startup.
- `no-auth-ssh` trusts the tunnel. Always pair it with `--allow`.
- Sessions run as the OS user running `serve`.
- `all` and `exit-node` expose every port, or the server's whole network.
  Use only on explicit request.

## Connecting

```sh
tailcat browse tc...                  # forward a free local port to :80 and open a browser (needs port 80 served)
tailcat forward tc... 8080            # local 8080 → remote 8080
tailcat forward tc... 18080:80        # local 18080 → remote 80
tailcat ssh user@tc...                # system ssh via a ProxyCommand
tailcat ssh tc... uptime
tailcat cp file.txt tc...:            # with the files service
tailcat ping --until-direct tc...     # relay vs direct path
```

Client modes use the `client-default` key automatically if it exists;
otherwise they use an ephemeral key, which `--allow` will reject.

## Identity in your own code

This API is on tailcat's main branch, after v0.7.0.

Embedding tailcat as a Go library (`github.com/tailscale/tailcat`):
`tailcat.Server{AllowClient: func(key.NodePublic) bool}` admits clients, and
`server.PeerKey(conn.RemoteAddr())` tells you which key is on a given
connection. That's enough to build per-person behaviour (for example, log
each guest into an app as themselves) with no passwords.

## Gotchas seen in practice

- After the server restarts, running `forward`/`browse` clients don't
  reconnect. Restart them.
- Adding a guest means restarting `serve` with the new `--allow` list.
- Relay latency depends on the region: guests far from it feel it on every
  request until a direct path forms (browsers never get one).
- `--region=auto` picks by measured latency. A local proxy or TUN (Clash,
  Surge, corporate VPN) answers every probe in ~1 ms, so the pick is arbitrary
  (seen: San Francisco for two people in Asia, with requests timing out). The
  same setups usually block UDP, so no direct path forms either. Pin the
  region next to the guest: `genkey --region=tok`, or `tailshare invite
  --region=tok`.
- A DNS TXT record (`tailcat=tc...`) can stand in for the address, but it's
  public: only do that with `--allow` or SSH keys in place.
