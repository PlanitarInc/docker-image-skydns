IMAGE_NAME=planitar/skydns

ifneq ($(NOCACHE),)
  NOCACHEFLAG=--no-cache
endif

.PHONY: build push clean test

build: bin/skydns
	docker build ${NOCACHEFLAG} -t ${IMAGE_NAME} .

push:
ifneq (${IMAGE_TAG},)
	docker tag -f ${IMAGE_NAME} ${IMAGE_NAME}:${IMAGE_TAG}
	docker push ${IMAGE_NAME}:${IMAGE_TAG}
else
	docker push ${IMAGE_NAME}
endif

clean:
	rm -rf ./bin ./logs
	docker rmi -f ${IMAGE_NAME} || true

test:
	./test.sh

bin/skydns:
	mkdir -p bin
	docker run --rm -v `pwd`/bin:/out planitar/dev-go /bin/bash -lc ' \
	  pkg="github.com/skynetservices/skydns" && \
	  gobldcp "$$pkg" skydns /out \
	'
