#!/bin/zsh
# Publishes the Mac mini's boot time + a heartbeat to the `status` branch.
# Each run force-pushes a single orphan commit, so the branch never grows history
# and the working tree is never touched.
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "${0:A:h}/.."

boot=$(sysctl -n kern.boottime | sed -E 's/.*sec = ([0-9]+),.*/\1/')
now=$(date +%s)
json=$(printf '{"boot_time":%s,"updated_at":%s}\n' "$boot" "$now")

blob=$(print -r -- "$json" | git hash-object -w --stdin)
tree=$(printf '100644 blob %s\tstatus.json\n' "$blob" | git mktree)
commit=$(git commit-tree "$tree" -m "status heartbeat $now")
git push -q -f origin "${commit}:refs/heads/status"
echo "$(date '+%F %T') pushed $json"
