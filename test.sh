#!/bin/bash

set -ex

export PATH=/in/bin:$PATH

# Set the nameserver
etcdctl --peers ${DOCKER_IP}:14001 \
  set /skydns/planitar/test/dns/ns \
  '{"host":"127.0.0.1", "priority":10, "weight":10}'
dig @${DOCKER_IP} -p1053 NS test.planitar | grep ^test.planitar. | \
  grep -w NS | grep -q ns.dns.test.planitar.
dig @${DOCKER_IP} -p1053 NS test.planitar | grep ^ns.dns.test.planitar. | \
  grep -w A | grep -q 127.0.0.1

#
etcdctl --peers ${DOCKER_IP}:14001 \
  set /skydns/planitar/test/a/01 \
  '{"host":"planitar.com", "port":9001, "priority":10, "weight":30}'
etcdctl --peers ${DOCKER_IP}:14001 \
  set /skydns/planitar/test/a/02 \
  '{"host":"example.com", "port":9002, "priority":10, "weight":10}'
etcdctl --peers ${DOCKER_IP}:14001 \
  set /skydns/planitar/test/b/01 \
  '{"host":"10.0.2.3", "port":9003, "priority":20}'

dig @${DOCKER_IP} -p1053 SRV 01.a.test.planitar | \
  grep -q '^01.a.test.planitar\..*.\<SRV\>.*\<10\>.*\<100\>.*\<9001\>.*planitar.com'
dig @${DOCKER_IP} -p1053 SRV 01.a.test.planitar | \
  grep -q '^planitar.com\..*.\<A\>'
dig @${DOCKER_IP} -p1053 SRV 02.a.test.planitar | \
  grep -q '^02.a.test.planitar\..*\<SRV\>.*\<10\>.*\<100\>.*\<9002\>.*\<example.com'
dig @${DOCKER_IP} -p1053 SRV 02.a.test.planitar | \
  grep -q '^example.com\..*.\<A\>'
dig @${DOCKER_IP} -p1053 SRV 01.b.test.planitar | \
  grep '^01.b.test.planitar\..*\<SRV\>.*\<20\>.*\<100\>.*\<9003\>.*\<01.b.test.planitar\>'
dig @${DOCKER_IP} -p1053 SRV 01.b.test.planitar | \
  grep -q '^01.b.test.planitar\..*.\<A\>.*\<10.0.2.3\>'

dig @${DOCKER_IP} -p1053 SRV a.test.planitar | \
  grep -q '^a.test.planitar\..*.\<SRV\>.*\<10\>.*\<75\>.*\<9001\>.*planitar.com'
dig @${DOCKER_IP} -p1053 SRV a.test.planitar | \
  grep -q '^a.test.planitar\..*.\<SRV\>.*\<10\>.*\<25\>.*\<9002\>.*example.com'

dig @${DOCKER_IP} -p1053 SRV test.planitar | \
  grep -q '^test.planitar\..*.\<SRV\>.*\<10\>.*\<60\>.*\<9001\>.*planitar.com'
dig @${DOCKER_IP} -p1053 SRV test.planitar | \
  grep -q '^test.planitar\..*.\<SRV\>.*\<10\>.*\<20\>.*\<9002\>.*example.com'
dig @${DOCKER_IP} -p1053 SRV test.planitar | \
  grep -q '^test.planitar\..*.\<SRV\>.*\<20\>.*\<100\>.*\<9003\>.*01.b.test.planitar'
