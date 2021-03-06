#!/bin/bash

set -ex

cleanup() {
  docker rm -f test-etcd test-skydns
}
report() {
  docker logs test-etcd
  docker logs --tail=all test-skydns
  echo "Test failed..."
}
trap report ERR
trap cleanup EXIT

DOCKER_IP=$(docker run --rm --net host planitar/base ip -4 a show docker0 | \
  sed 's@^\s*inet \([0-9][0-9.]*\)/.*$@\1@p' -n)

docker run -d --name test-etcd \
  -p ${DOCKER_IP}:14001:2379 \
  planitar/etcd \
    etcd \
      --listen-client-urls http://0.0.0.0:2379 \
      --advertise-client-urls http://${DOCKER_IP}:14001

sleep 5s

docker run -d --name test-skydns \
  -p ${DOCKER_IP}:1053:53/udp \
  planitar/skydns \
    -addr 0.0.0.0:53 \
    -nameservers 8.8.8.8:53 \
    -machines http://${DOCKER_IP}:14001 \
    -domain test.planitar. \
    -verbose

sleep 1s

docker run --rm -v `pwd`:/in \
  -e DOCKER_IP=${DOCKER_IP} \
  -e ETCD_ADDR=${DOCKER_IP}:14001 \
  planitar/dev-base \
    /in/test-cases.sh
