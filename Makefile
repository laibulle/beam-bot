init: asdf
	docker compose up -d

stop:
	docker compose down

asdf:
	asdf install

assets:
	cd assets && npm i

.PHONY: init stop asdf assets

build-docker-image:
	docker build --no-cache -t laibulle/beam-bot:latest .

push-docker-image:
	docker push laibulle/beam-bot:latest

.PHONY: init stop asdf assets build-docker-image push-docker-image

deploy: build-docker-image push-docker-image
	cd ../infra && make install-beambot 
