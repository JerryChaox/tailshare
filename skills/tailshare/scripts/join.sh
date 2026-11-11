#!/bin/sh
# Accept a tailshare invite: install tailcat, knock on the host's lobby,
# wait for approval, then open the shared port in a browser.
# usage: join.sh tc<lobby-address> [name]
set -eu

lobby=${1:?usage: join.sh tc<lobby-address> [name]}
name=${2:-$(id -un)}
key=${TAILSHARE_CLIENT_KEY:-client-default}

if ! command -v tailcat >/dev/null; then
	command -v brew >/dev/null || { echo "Install tailcat first: https://github.com/tailscale/tailcat/releases" >&2; exit 1; }
	brew install tailcat
fi
# The private half stays in tailcat's key folder; only the public key reaches the host.
tailcat genkey --list 2>/dev/null | grep -qx "$key" || tailcat genkey --client --key="$key" >/dev/null

echo "Knocking as $name; waiting for the host to approve..." >&2
reply=$(printf '%s\n' "$name" | tailcat --key="$key" "$lobby" 2>/dev/null) || true
set -- $reply
case ${1:-} in
ok) addr=$2 ports=$3 ;;
deny) echo "The host declined." >&2; exit 1 ;;
timeout) echo "The host didn't answer in time; ask them and run this again." >&2; exit 1 ;;
*) echo "Couldn't reach the lobby; the invite may be closed." >&2; exit 1 ;;
esac

# Local port 0 picks a free port, so a guest's own dev server on the same port doesn't clash.
maps=$(echo "$ports" | tr ',' '\n' | sed 's/^/0:/')
set -- --key="$key"
[ "$(echo "$maps" | wc -l)" -eq 1 ] && set -- "$@" --open-browser
echo "Approved. To reconnect later: tailcat forward $addr <local>:<port>  (keep this address private)" >&2
exec tailcat forward "$@" "$addr" $maps
