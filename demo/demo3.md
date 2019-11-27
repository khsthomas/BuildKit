```sh
export LLB=bake-buildkit
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

docker-compose -f docker-compose.yml -f buildx.yml config

docker buildx bake -f docker-compose.yml -f buildx.yml --print

time docker buildx bake -f docker-compose.yml -f buildx.yml --no-cache

docker images

time docker buildx bake -f docker-compose.yml -f buildx.yml --no-cache
```
