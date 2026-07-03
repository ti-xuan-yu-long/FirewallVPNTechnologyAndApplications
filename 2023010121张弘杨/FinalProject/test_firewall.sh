#!/usr/bin/env bash

echo "Test 1: office -> dmz:8080 (should success)"
ip netns exec office bash -c "timeout 3 bash -c 'echo ok > /dev/tcp/10.40.0.2/8080' && echo PASS || echo FAIL"

echo "Test 2: office -> dmz:22 (should fail)"
ip netns exec office bash -c "timeout 2 bash -c 'echo ok > /dev/tcp/10.40.0.2/22' && echo FAIL || echo PASS"

echo "Test 3: guest -> office (should fail)"
ip netns exec guest bash -c "timeout 2 bash -c 'echo ok > /dev/tcp/10.20.0.2/8000' && echo FAIL || echo PASS"

echo "Test 4: guest -> dmz (should fail)"
ip netns exec guest bash -c "timeout 2 bash -c 'echo ok > /dev/tcp/10.40.0.2/8080' && echo FAIL || echo PASS"

echo "Test 5: guest -> internet (should success)"
ip netns exec guest bash -c "timeout 3 bash -c 'echo ok > /dev/tcp/203.0.113.10/80' && echo PASS || echo FAIL"

echo "Test 6: office -> internet (should success)"
ip netns exec office bash -c "timeout 3 bash -c 'echo ok > /dev/tcp/203.0.113.10/80' && echo PASS || echo FAIL"

echo "Test 7: internet -> 203.0.113.1:80 (DNAT, should success)"
ip netns exec internet bash -c "timeout 3 bash -c 'echo ok > /dev/tcp/203.0.113.1/80' && echo PASS || echo FAIL"

echo "Test 8: internet -> dmz:22 (should fail)"
ip netns exec internet bash -c "timeout 2 bash -c 'echo ok > /dev/tcp/203.0.113.1/22' && echo FAIL || echo PASS"
