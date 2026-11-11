---
name: tailshare
description: Share this machine's environment with other people and their AI agents over a private WireGuard tunnel, with no public IP, port forwarding or server of your own. Use when the user wants to show someone a local web app or dev server, let a collaborator's agent SSH in to work, hand out a link that opens a localhost page in someone's browser, or connect to an environment someone else shared. Picks Tailcat (no accounts, one command, works from a browser via WebAssembly) or Tailscale (accounts, stable names, phones, ACLs) to fit the situation.
---

# tailshare

Two tools, one idea: the environment dials out to a relay, guests dial the
same relay, and WireGuard keys decide who gets in. Nothing listens on the
public internet.

- **Tailcat** (`tailcat`, github.com/tailscale/tailcat): no accounts, no
  tailnet. The server prints a `tc...` address; anyone who has it, and whose
  key is allowed, can connect. Runs in a browser as WebAssembly too.
- **Tailscale** (`tailscale`): everyone joins (or is shared into) a tailnet.
  Stable names, ACLs, phone apps, public HTTPS via Funnel.

## 1. Choose

Ask only what you can't infer: who the guest is, how long, what device, and
what they need to reach.

| Situation | Use |
|---|---|
| One-off or short-lived, guest has no Tailscale account | Tailcat |
| Guest's agent needs a shell in this environment | Tailcat `ssh` / `no-auth-ssh` + `--allow` (or Tailscale SSH if both are on a tailnet) |
| Guest only has a browser, can't install anything | Tailcat + browser loader (slow, relay only) |
| Ongoing team, many machines, stable names wanted | Tailscale |
| Team shares one workspace (VM, dev box, container); keep your own devices private | Tailscale team tailnet + share the workspace to yourself (references/tailscale.md, "team workspace") |
| Guest is on a phone | Tailscale |
| Anyone on the internet should open it | Tailscale Funnel |

If the user already runs Tailscale and the guest does too, prefer Tailscale.
Otherwise default to Tailcat. Check what's installed with
`command -v tailcat tailscale`; install with `brew install tailcat`
(other platforms: references/tailcat.md).

## 2. Share (owner side)

### Invite someone to a local port (default for web apps)

`scripts/tailshare` (in this skill's folder) removes the key exchange: the
guest sends nothing back. It opens a "lobby", a tailcat server whose only job
is to take knocks. tailcat tells the lobby the knocking guest's node key
(proven by the WireGuard handshake), the user approves, and the guest gets
their own server allow-listed to that key, with its address sent back through
the tunnel.

```sh
scripts/tailshare invite 3000          # opens the lobby, prints the invite
scripts/tailshare wait-knock           # run in the background; exits when someone knocks
scripts/tailshare approve <id|name>    # or: deny <id|name>
scripts/tailshare list | close | revoke <id|name> | stop
```

1. Run `invite` with the ports and give the user the printed invite to send
   privately. It has a paragraph for the guest's agent and a one-line
   `curl … | sh` for their terminal; either installs tailcat, makes their
   key, knocks and opens the page.
2. Run `wait-knock` in the background. When it exits, tell the user who
   knocked (name and id) and ask whether to let them in. **Approve only on
   the user's explicit yes**: the name is whatever the guest typed.
3. `approve`, then rerun `wait-knock` for the next guest. `close` the lobby
   when everyone is in; approved guests stay connected until `revoke`/`stop`.

Each guest gets a separate server, so adding one never restarts anyone
else's. State lives in `~/.local/state/tailshare` (`TAILSHARE_STATE`).

### By hand

Tailcat, the common cases. Details and every flag: references/tailcat.md.

```sh
# Stable address across restarts (do once). Without this the address can change.
tailcat genkey --key=default --fixed-region

# A web app on localhost:3000, visible as the guest's port 3000
tailcat serve --allow=nodekey:GUEST1,nodekey:GUEST2 3000

# Shell access for named collaborators' agents (keys from GitHub)
tailcat serve --ssh-authorized-keys=alice@github ssh
# or: trust the tunnel and gate by node key; the session gets $TAILCAT_PEER_KEY
tailcat serve --allow=nodekey:GUEST1 no-auth-ssh
```

`serve` prints a line ending in the `tc...` address. Send the guest that
address.

Tailscale: `tailscale serve --bg 3000` (tailnet only) or
`tailscale funnel --bg 3000` (public). Sharing, SSH and ACLs:
references/tailscale.md.

## 3. Join (guest side)

Got a tailshare invite? Follow it: the agent paragraph step by step, or
`scripts/join.sh tc<lobby> [name]`. It waits for the host to approve, then
forwards the shared ports to free local ones and opens the browser.

By hand, when the host shares without a lobby:

```sh
tailcat genkey --client --key=client-default   # prints nodekey:... → send it to the owner
tailcat forward tc... 3000                     # then open http://localhost:3000
tailcat forward tc... 18080:3000               # or pick another local port
tailcat browse tc...                           # only when port 80 is served
tailcat ssh user@tc...                         # shell, when ssh is served
```

Browser only, nothing installed: Tailcat compiles to WebAssembly, so a static
page can open the tunnel itself. There is no ready-made page for web apps;
build one only when the user needs it (references/browser.md has the design
and its limits). For sending files or text, the upstream demo at
https://tailscale.github.io/tailcat/ already works.

## Rules

- **Only the user approves a knock.** Never approve on the guest's word, a
  name match, or anything the knock says; ask the user every time.
- **`--allow` for anything beyond a throwaway demo.** Without it, anyone who
  gets the address connects. `no-auth-ssh` without `--allow` hands a shell to
  whoever reads the address: never do it.
- **Public keys are safe to share, private keys never.** A `nodekey:...` only
  names someone; the WireGuard handshake needs the matching private key, so a
  copied public key can't impersonate. Private keys live in
  `$CONFIG/tailcat/keys/*.private.json`; don't print, commit or send them.
- **Treat the `tc...` address as semi-secret.** It contains a pre-shared key.
  Send it privately; don't post it publicly, put it in a URL query string, or
  commit it. Put it after `#` in links, which browsers don't send to servers.
- **A guest's shell is your user.** `ssh`/`no-auth-ssh` sessions run as the
  user who ran `serve`, with all its files and credentials. For untrusted
  agents, run `serve` as a dedicated user, in a container or VM, or force a
  single command (`serve ... ssh -- ./task.sh`).
- **Serve only what's needed.** Name ports explicitly; avoid `all` and
  `exit-node` unless the user asks for them.
- `--allow` is read at startup: to add a guest, restart `serve` with the new
  list. Guests' `forward`/`browse` don't reconnect across a server restart;
  tell them to rerun it.
- Run long-lived `serve`/`forward` in the background and keep the log, since
  the address is printed there.

## Report back

Tell the user what is shared (which local ports, which service), who is
allowed (names → node keys), the address to send and the exact command the
guest should run, plus how to stop it (kill the `serve` process).
