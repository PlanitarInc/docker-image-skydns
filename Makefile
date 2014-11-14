IMAGE_NAME=planitar/skydns

ifneq ($(NOCACHE),)
  NOCACHEFLAG=--no-cache
endif

DOCKER_IP=$(shell ifconfig docker0  | sed -n 's/^.*\<inet addr:\([0-9.]\+\).*$$/\1/p')

.PHONY: build push clean test

build: bin/skydns
	docker build ${NOCACHEFLAG} -t ${IMAGE_NAME} .

push:
	docker push ${IMAGE_NAME}

clean:
	rm -rf ./bin
	docker rmi -f ${IMAGE_NAME} || true

test: bin/etcd bin/etcdctl
	docker run -d --name test-etcd -v `pwd`/bin:/in \
	  -p ${DOCKER_IP}:14001:14001 planitar/dev-base \
	  /in/etcd -addr ${DOCKER_IP}:14001 -bind-addr 0.0.0.0
	docker run -d --name test-skydns -p ${DOCKER_IP}:1053:53/udp \
	  ${IMAGE_NAME} -addr 0.0.0.0:53 -nameservers 8.8.8.8:53 \
	  -machines http://${DOCKER_IP}:14001 -domain test.planitar. -verbose
	sleep 1s
	
	PATH=./bin:$$PATH DOCKER_IP=${DOCKER_IP} ./test.sh >logs.test.txt 2>&1; \
	res=$$?; \
	if [ $$res -ne 0 ]; then \
	  docker logs test-etcd > logs.etcd.txt; \
	  docker logs test-skydns > logs.skydns.txt; \
	  echo "    Logs are at `pwd`/logs.etcd.txt `pwd`/logs.skydns.txt `pwd`/logs.test.txt"; \
	  echo ""; \
	  tail logs.test.txt; \
	  docker rm -f test-etcd test-skydns; \
	  false; \
	fi
	docker rm -f test-etcd test-skydns
	rm -f logs.test.txt

bin/skydns:
	mkdir -p bin
	docker run --rm -v `pwd`/bin:/out planitar/dev-go /bin/bash -lc ' \
	  go get "github.com/skynetservices/skydns" && \
	  cp $$GOPATH/bin/skydns /out \
	'

bin/etcd bin/etcdctl:
	mkdir -p bin
	docker run --rm -v `pwd`/bin:/out planitar/dev-go /bin/bash -lc ' \
	  wget https://github.com/coreos/etcd/releases/download/v0.4.6/etcd-v0.4.6-linux-amd64.tar.gz && \
	  tar xzvf etcd-v0.4.6-linux-amd64.tar.gz && \
	  cp etcd-v0.4.6-linux-amd64/etcd /out && \
	  cp etcd-v0.4.6-linux-amd64/etcdctl /out \
	'
