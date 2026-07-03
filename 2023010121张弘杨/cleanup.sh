#!/usr/bin/env bash
set +e

for ns in fw office guest dmz internet remote; do
    ip netns exec "$ns" ip link delete wg0 2>/dev/null
    ip netns del "$ns" 2>/dev/null
done

rm -rf /tmp/wgkeys

echo "Cleanup complete"
