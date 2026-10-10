#!/bin/zsh
# Publishes the Mac mini's boot time, a heartbeat, CPU temp and memory to the `status` branch.
# Each run force-pushes a single orphan commit, so the branch never grows history
# and the working tree is never touched.
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "${0:A:h}/.."

boot=$(sysctl -n kern.boottime | sed -E 's/.*sec = ([0-9]+),.*/\1/')
now=$(date +%s)

# One macmon sample (sudoless Apple Silicon sensors). Metrics are best-effort:
# if macmon fails, uptime still gets published with the metrics set to null.
sample=$(macmon pipe -s 1 -i 1000 2>/dev/null || true)
json=$(print -r -- "$sample" | /usr/bin/python3 -I -c '
import json, sys
boot, now = int(sys.argv[1]), int(sys.argv[2])
try:
    s = json.loads(sys.stdin.read())
    m = s["memory"]
    metrics = {
        "cpu_temp_c": round(s["temp"]["cpu_temp_avg"], 1),
        "mem_used": m["ram_usage"], "mem_total": m["ram_total"],
        "swap_used": m["swap_usage"], "swap_total": m["swap_total"],
    }
except Exception:
    metrics = {"cpu_temp_c": None, "mem_used": None, "mem_total": None, "swap_used": None, "swap_total": None}
print(json.dumps({"boot_time": boot, "updated_at": now, **metrics}))
' "$boot" "$now")

blob=$(print -r -- "$json" | git hash-object -w --stdin)
tree=$(printf '100644 blob %s\tstatus.json\n' "$blob" | git mktree)
commit=$(git commit-tree "$tree" -m "status heartbeat $now")
git push -q -f origin "${commit}:refs/heads/status"
echo "$(date '+%F %T') pushed $json"
