init: asdf
	docker compose up -d

stop:
	docker compose down

asdf:
	asdf install

test:
	mix test
	
coverage:
	mix coveralls.cobertura

assets:
	cd assets && npm i

.PHONY: init stop asdf assets

build-docker-image:
	docker build --no-cache -t laibulle/beam-bot:latest .

push-docker-image:
	docker push laibulle/beam-bot:latest

deploy: build-docker-image push-docker-image
	cd ../infra && make install-beambot 



.PHONY: init stop asdf assets build-docker-image push-docker-image coverage test