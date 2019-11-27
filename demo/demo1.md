```sh
yes | docker system prune -a

export LLB=docker-compose-without-buildkit
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0

docker-compose config
docker-compose build --parallel > /dev/null 2>&1

time docker-compose build --parallel --no-cache

docker images

time docker-compose build --parallel
```
