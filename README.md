# tailshare

An agent skill for sharing your dev environment with people and their AI
agents over a private WireGuard tunnel: no public IP, no port forwarding, no
server of your own.

Ask your agent things like:

- "Let Alice see the app on port 3000."
- "Let Bob's agent SSH in and fix the failing test."
- "Connect me to the environment Carol sent me: tc..."

It picks the right tool for the job:

- **[Tailcat](https://github.com/tailscale/tailcat)**: no accounts, one command
  on each side, and it can even run in a browser as WebAssembly. Good for
  ad-hoc sharing with anyone.
- **[Tailscale](https://tailscale.com)**: stable names, ACLs, phone apps, and
  public HTTPS via Funnel. Good for ongoing teams.

Then it runs the commands with safe defaults: an allow-list of keys,
explicit ports, and no public addresses.

## Install

Claude Code:

```sh
git clone https://github.com/JerryChaox/tailshare ~/.claude/skills/tailshare
```

For other agents that read `SKILL.md` skills, clone it into that agent's
skills folder.

You also need `tailcat` (`brew install tailcat`; other platforms are listed in
[references/tailcat.md](references/tailcat.md)) and/or `tailscale`.

## How it works

```
your machine ── outbound ──▶ relay (DERP) ◀── outbound ── guest
      └──────────── WireGuard, end to end ─────────────┘
```

Both sides dial out, so nothing listens on the internet. The relay only
forwards encrypted packets and tries to set up a direct path. Who gets in is
decided by WireGuard keys: the guest sends you a public `nodekey:...`, and you
add it to `--allow`. A copied public key can't impersonate anyone, because
the handshake needs the matching private key.

## What's inside

- [SKILL.md](SKILL.md): when to use which tool, the share/join recipes and
  the safety rules
- [references/tailcat.md](references/tailcat.md): commands, keys, address
  stability and gotchas
- [references/tailscale.md](references/tailscale.md): serve, funnel, node
  sharing and SSH
- [references/browser.md](references/browser.md): opening a shared web app
  from a browser with nothing installed (Tailcat in WebAssembly plus a
  Service Worker), and its limits

Not affiliated with Tailscale. MIT licensed.
