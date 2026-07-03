#!/usr/bin/env bash

echo "=== Starting HTTP services ==="

ip netns exec dmz bash -c 'python3 -m http.server 8080 >/dev/null 2>&1 &'
echo "dmz:8080 started"

ip netns exec office bash -c 'python3 -m http.server 8000 >/dev/null 2>&1 &'
echo "office:8000 started"

ip netns exec internet bash -c 'python3 -m http.server 80 >/dev/null 2>&1 &'
echo "internet:80 started"

sleep 1
echo "=== Services started ==="
