#!/usr/bin/env bash

echo "Test 1: remote -> office:8000 (should success)"
ip netns exec remote bash -c "timeout 3 bash -c 'echo ok > /dev/tcp/10.20.0.2/8000' && echo PASS || echo FAIL"

echo "Test 2: remote -> dmz:8080 (should success)"
ip netns exec remote bash -c "timeout 3 bash -c 'echo ok > /dev/tcp/10.40.0.2/8080' && echo PASS || echo FAIL"

echo "Test 3: remote -> dmz:22 (should fail)"
ip netns exec remote bash -c "timeout 2 bash -c 'echo ok > /dev/tcp/10.40.0.2/22' && echo FAIL || echo PASS"

echo "Test 4: remote -> guest (should fail)"
ip netns exec remote bash -c "timeout 2 bash -c 'echo ok > /dev/tcp/10.30.0.2/80' && echo FAIL || echo PASS"
