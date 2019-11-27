```sh
yes | docker system prune -a

export LLB=docker-compose-with-buildkit
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

time docker-compose build --parallel

docker images
```
