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
	docker build -t beam-bot .

.PHONY: init stop asdf assets build-docker-image