IMAGE_NAME=planitar/skydns

ifneq ($(NOCACHE),)
  NOCACHEFLAG=--no-cache
endif

.PHONY: build push clean test

build: bin/skydns
	docker build ${NOCACHEFLAG} -t ${IMAGE_NAME} .

push:
	docker push ${IMAGE_NAME}

clean:
	rm -rf ./bin ./logs
	docker rmi -f ${IMAGE_NAME} || true

test: bin/etcd bin/etcdctl
	mkdir -p logs
	DOCKER_IP=$$(docker run --net host --rm planitar/dev-base \
	  bash -c "ifconfig docker0" | \
	  sed -n "s/^.*\<inet addr:\([0-9.]\+\).*$$/\1/p"); \
	docker run -d --name test-etcd -v `pwd`/bin:/in \
	  -p $${DOCKER_IP}:14001:14001 planitar/dev-base \
	  /in/etcd -addr $${DOCKER_IP}:14001 -bind-addr 0.0.0.0; \
	docker run -d --name test-skydns -p $${DOCKER_IP}:1053:53/udp \
	  ${IMAGE_NAME} -addr 0.0.0.0:53 -nameservers 8.8.8.8:53 \
	  -machines http://$${DOCKER_IP}:14001 -domain test.planitar. -verbose; \
	sleep 1s; \
	docker run --rm -v `pwd`:/in -v `pwd`/logs:/logs \
	  -e DOCKER_IP=$${DOCKER_IP} planitar/dev-base /in/test.sh \
	  >logs/logs.test.txt 2>&1; \
	res=$$?; \
	if [ $$res -ne 0 ]; then \
	  docker logs test-etcd > logs/logs.etcd.txt; \
	  docker logs test-skydns > logs/logs.skydns.txt; \
	  echo "    Logs are at `pwd`/logs/logs.etcd.txt `pwd`/logs/logs.skydns.txt `pwd`/logs/logs.test.txt"; \
	  echo ""; \
	  tail logs/logs.test.txt; \
	  docker rm -f test-etcd test-skydns; \
	  false; \
	fi
	docker rm -f test-etcd test-skydns
	rm -rf logs

bin/skydns:
	mkdir -p bin
	docker run --rm -v `pwd`/bin:/out planitar/dev-go /bin/bash -lc ' \
	  pkg="github.com/skynetservices/skydns" && \
	  gobldcp "$$pkg" skydns /out \
	'

bin/etcd bin/etcdctl:
	mkdir -p bin
	docker run --rm -v `pwd`/bin:/out planitar/dev-go /bin/bash -lc ' \
	  wget https://github.com/coreos/etcd/releases/download/v0.4.6/etcd-v0.4.6-linux-amd64.tar.gz && \
	  tar xzvf etcd-v0.4.6-linux-amd64.tar.gz && \
	  cp etcd-v0.4.6-linux-amd64/etcd /out && \
	  cp etcd-v0.4.6-linux-amd64/etcdctl /out \
	'
