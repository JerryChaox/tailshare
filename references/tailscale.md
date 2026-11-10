# Tailscale reference

For when both sides can be on a tailnet. Commands checked against
Tailscale 1.102. `tailscale <cmd> --help` and tailscale.com/kb are the
source of truth.

## Sharing a local server

```sh
tailscale serve --bg 3000          # https://<machine>.<tailnet>.ts.net → localhost:3000, tailnet only
tailscale serve status
tailscale serve reset

tailscale funnel --bg 3000         # same, but public on the internet
tailscale funnel reset
```

- `serve` needs HTTPS certificates and MagicDNS enabled on the tailnet; the
  first run prints a link if they aren't.
- Funnel needs the `funnel` node attribute in the tailnet policy and only
  uses ports 443, 8443, 10000. Anyone with the URL reaches the app, so the
  app must do its own auth.
- Requests proxied by `serve` carry `Tailscale-User-Login` /
  `Tailscale-User-Name` headers: the app can trust them for identity (not
  for Funnel traffic).

## Letting someone in

- **Share one machine** with a person outside your tailnet: admin console →
  Machines → the machine → Share. They accept with their own Tailscale
  account and see only that machine.
- **Invite to the tailnet** for ongoing teams; restrict with ACLs/grants so
  guests reach only the ports you mean.
- **Phones** work through the Tailscale iOS/Android apps; Tailcat has no
  phone client.

## Agents over SSH

```sh
tailscale set --ssh
```

Then allow it in the tailnet policy, for example:

```json
"ssh": [{"action": "accept", "src": ["alice@example.com"], "dst": ["tag:shared"], "users": ["agent"]}]
```

Their agent runs `ssh agent@<machine>` (or `tailscale ssh`). Prefer a
dedicated local user (`users: ["agent"]`) over your own.

## Identity

`tailscale whois <tailscale-ip>` maps a connection to a user and machine.

## Tailcat vs Tailscale at a glance

| | Tailcat | Tailscale |
|---|---|---|
| Accounts | none | both sides |
| Setup | one command per side | install, log in, share/invite |
| Address | `tc...` string, changes unless the key is fixed | stable MagicDNS name |
| Access control | `--allow` node keys, SSH keys | ACLs/grants, per user and tag |
| Browser-only guest | yes, WASM loader (relay only) | no (Funnel is public instead) |
| Phones | no | yes |
| Public HTTPS | no | Funnel |
