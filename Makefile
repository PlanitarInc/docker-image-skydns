# XXX no versioning of the docker image

DOCKER_IP = 172.17.42.1

.PHONY: build push clean test

build: bin/skydns
	docker build -t planitar/skydns .

push:
	docker push planitar/skydns

clean:
	rm -rf ./bin
	docker rmi -f planitar/skydns 2> /dev/null || true

test: bin/etcd bin/etcdctl
	docker run -d --name test-etcd -v `pwd`/bin:/in \
	  -p ${DOCKER_IP}:14001:14001 planitar/dev-base \
	  /in/etcd -addr ${DOCKER_IP}:14001 -bind-addr 0.0.0.0
	docker run -d --name test-skydns -p ${DOCKER_IP}:1053:53/udp \
	  planitar/skydns -addr 0.0.0.0:53 -nameservers 8.8.8.8:53 \
	  -machines http://${DOCKER_IP}:14001 -domain test.planitar. -verbose
	sleep 1s
	
	@# Set the nameserver
	./bin/etcdctl --peers ${DOCKER_IP}:14001 \
	  set /skydns/planitar/test/dns/ns \
	  '{"host":"127.0.0.1", "priority":10, "weight":10}'
	dig @${DOCKER_IP} -p1053 NS test.planitar | grep ^test.planitar. | \
	  grep -w NS | grep -q ns.dns.test.planitar.
	dig @${DOCKER_IP} -p1053 NS test.planitar | grep ^ns.dns.test.planitar. | \
	  grep -w A | grep -q 127.0.0.1
	
	@#
	./bin/etcdctl --peers ${DOCKER_IP}:14001 \
	  set /skydns/planitar/test/a/01 \
	  '{"host":"planitar.com", "port":9001, "priority":10, "weight":30}'
	./bin/etcdctl --peers ${DOCKER_IP}:14001 \
	  set /skydns/planitar/test/a/02 \
	  '{"host":"example.com", "port":9002, "priority":10, "weight":10}'
	./bin/etcdctl --peers ${DOCKER_IP}:14001 \
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

bin/skydns:
	mkdir -p bin
	docker run --rm -v `pwd`/bin:/out planitar/dev-go /bin/bash -lc ' \
	  go get "github.com/skynetservices/skydns" && \
	  cp $$GOPATH/bin/skydns /out \
	'

bin/etcd:
	mkdir -p bin
	docker run --rm -v `pwd`/bin:/out planitar/dev-go /bin/bash -lc ' \
	  go get "github.com/coreos/etcd" && \
	  cp $$GOPATH/bin/etcd /out \
	'

bin/etcdctl:
	mkdir -p bin
	docker run --rm -v `pwd`/bin:/out planitar/dev-go /bin/bash -lc ' \
	  go get "github.com/coreos/etcdctl" && \
	  cp $$GOPATH/bin/etcdctl /out \
	'
