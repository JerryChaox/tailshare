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

## Pattern: a team workspace, kept apart from your personal tailnet

Use this when a team works in one shared environment that runs an app or
agent sessions. You want to use it from your own devices, but teammates must
not reach your devices, or each other.

The workspace can be anything that runs `tailscaled`: a cloud VM, a dev box
or home server, a local VM, or a container. In a container, use the
`tailscale/tailscale` image or run `tailscaled --tun=userspace-networking`,
and join with an auth key tagged `tag:workspace`.

```
 YOUR PERSONAL TAILNET        TEAM TAILNET
┌─────────────────────┐     ┌───────────────────────────────┐
│  your other devices │     │        team workspace         │
│         │           │     │  ┌─────────────────────┐      │
│      your Mac ══════╪═════╪═▶│ shared app :6768    │      │
│                     │share│  └─────────────────────┘      │
└─────────────────────┘     │     ▲               ▲         │
                            │     ║               ║         │
                            │  teammate A      teammate B   │
                            │     ✕ ───────────── ✕         │
                            └───────────────────────────────┘
 ═══▶ allowed, direct to the workspace     ✕──✕ blocked by the team policy
```

Setup:

1. Create a separate **team tailnet**. Put the workspace in it with a tag (say
   `tag:workspace`) and invite teammates as users.
2. Replace the team tailnet's default allow-all policy with a grant that
   only lets the team reach the workspace's port:

   ```json
   {
     "groups":    {"group:team": ["a@example.com", "b@example.com"]},
     "tagOwners": {"tag:workspace": ["autogroup:admin"]},
     "grants": [
       {"src": ["group:team"], "dst": ["tag:workspace"], "ip": ["tcp:6768"]}
     ]
   }
   ```

   Nothing else is granted, so teammates can't reach each other and the
   workspace can't reach them. Add `tcp:22` or an `ssh` rule only if agents need a
   shell.
3. **Share the workspace into your personal tailnet** (admin console → Machines →
   the workspace → Share) and accept it with your personal account. Your Mac then
   reaches the workspace, and your personal devices stay invisible to the team.

| Connection | Result |
|---|---|
| Your Mac → workspace | Allowed, through the share |
| Teammate → workspace | Allowed, on the granted port only |
| Teammate → your Mac or your other devices | Blocked, different tailnet |
| Teammate ↔ teammate | Blocked by the team policy |
| Workspace → your Mac | Blocked, shared machines can't start connections |
| Workspace → teammates | Blocked by the team policy |
| Your Mac → your other devices | Unchanged |

Everyone talks to the same service on the workspace, so they all see the same
state (for example, the same session list). Tailscale's coordination
server only sets up connections, and its relays are a fallback; traffic
stays end-to-end encrypted.

**Test the two parts that can be wrong:**

- The share: from your Mac, reach `<workspace>:6768`. From the workspace, try to reach
  your Mac (it should fail).
- The policy: from teammate A, reach `<workspace>:6768` (it should work), then
  teammate B and another workspace port (both should fail). Test with real
  connections (`curl`, `nc -vz`): `tailscale ping` checks the network path
  and doesn't go through the policy, so it isn't a policy test.

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
