# Buildkit, buildx and docker-compose

<!-- TOC -->

- [Buildkit, buildx and docker-compose](#buildkit-buildx-and-docker-compose)
	- [docker-compose](#docker-compose)
	- [BuildKit](#buildkit)
		- [LLB](#llb)
		- [Key features:](#key-features)
	- [Dockerfile frontend experimental syntaxes](#dockerfile-frontend-experimental-syntaxes)
	- [buildx](#buildx)
- [Implementation](#implementation)
	- [docker-compose override](#docker-compose-override)
	- [new Dockerfile](#new-dockerfile)
		- [mount=type=cache](#mounttypecache)
			- [id](#id)
			- [sharing](#sharing)
		- [RUN --mount=type=secret](#run---mounttypesecret)
	- [buildx bake](#buildx-bake)
		- [Gotchas](#gotchas)
- [Bibliography](#bibliography)
	- [BuildKit](#buildkit-1)
	- [Buildx](#buildx)
	- [Dockerfile frontend experimental syntaxes](#dockerfile-frontend-experimental-syntaxes-1)

<!-- /TOC -->


## docker-compose

Historically, I have been using `docker-compose` to both run and build docker images, both locally and with automation.

> `docker-compose` is a tool for defining and running multi-container Docker applications. With Compose, you use a YAML file to configure your application’s services. Then, with a single command, you create and start all the services from your configuration.

docker-compose wraps around `docker build`, despite some improvements there are still serious limitations

After the launch of `multi-stage build` feature for docker build, users requests many similar additions.


## BuildKit

> BuildKit is a new project under the Moby umbrella for building and packaging software using containers. It’s a new codebase meant to replace the internals of the current build features in the Moby Engine.
> From the performance side, a significant update is a new fully concurrent build graph solver. It can run build steps in parallel when possible and optimize out commands that don’t have an impact on the final result.


### LLB

> At the core of BuildKit is a new low-level build definition format called LLB (low-level builder). This is an intermediate binary format that end users are not exposed to but allows to easily build on top of BuildKit. LLB defines a content-addressable dependency graph that can be used to put together very complex build definitions. It also supports features not exposed in Dockerfiles, like direct data mounting and nested invocation.

> A frontend is a component that takes a human-readable build format and converts it to LLB so BuildKit can execute it. Frontends can be distributed as images, and the user can target a specific version of a frontend that is guaranteed to work for the features used by their definition. For example, to build a Dockerfile with BuildKit, you would use an external Dockerfile frontend. Check out the examples of using Dockerfiles with BuildKit with a development version of such image.


### Key features:

* Automatic garbage collection
* Extendable frontend formats
* Concurrent dependency resolution
* Efficient instruction caching
* Build cache import/export
* Nested build job invocations
* Distributable workers
* Multiple output formats
* Pluggable architecture
* Execution without root privileges

As a engineer that produces many docker images, the most interesting points from this list are:
* Efficient instruction caching;
> allows for the order in the `Dockerfile` to no matter as much as it did before, when optimising cache bust.
* Concurrent dependency resolution;
> As good practice, our Dockerfiles use multi-layers,to optimise time and storage for each layer.
With this improvement, stages that are not needed can be skipped.
* Build cache import/export;
> We are able to export the export the cache to a docker repository, and layer pull it before building, saving considerable amount of time for very large builds.


## Dockerfile frontend experimental syntaxes

While developing the new BuildKit interface, a new set of options were introduced.
You can enable them on docker v18.06 and v19 by `export DOCKER_BUILDKIT=1` and add `# syntax=docker/dockerfile:experimental` as the 1st line of your Dockerfile.

Building a Dockerfile with experimental features like `RUN --mount=type=(bind|cache|tmpfs|secret|ssh)`

For me the most interesting of these are:

* RUN --mount=type=cache
> This mount type allows the build container to cache directories for compilers and package managers.

This becomes super useful to use with NPM, Maven or APK/APT.
The packages are stored outside of the docker layer, in a volume cache in the host.
Other build executions or layers can then access that cache, avoiding to download again.

* RUN --mount=type=secret
> This mount type allows the build container to access secure files such as private keys without baking them into the image.

You can now execute limited scope RUNs, exposing your secrets just to that layer, instead of the all build.


## buildx

> Docker CLI plugin for extended build capabilities with BuildKit

* Familiar UI from docker build
* Full BuildKit capabilities with container driver
* Multiple builder instance support
* Multi-node builds for cross-platform images
* Compose build support

So, buildx is a _drop-in replacement_ for Docker build, supercharging it with many of BuildKit features.

After installing the plug-in, you can enable it executing `docker buildx install`.

For me the most interesting feature of buildx is `bake`.

> Currently, the bake command supports building images from compose files, similar to compose build but allowing all the services to be built concurrently as part of a single request.
There is also support for custom build rules from HCL/JSON files allowing better code reuse and different target groups. The design of bake is in very early stages and we are looking for feedback from users.

This allows us with minimal effort and a simple override file to use a `docker-compose.yaml` file with buildx.


# Implementation

## docker-compose override

We begin with creating an override file to our usual `docker-compose.yml` file.
This is required cause the way docker-compose and bake handle `context` path is different.

You can find one of such files at: [ buildx.yml ]( buildx.yml )

In there we override the context path and also the name of the dockerfile, since we will using a new file to to add the extra features of BuildKit.


## new Dockerfile

Let's compare [ Dockerfile-node-buildkit ]( Dockerfile-node-buildkit ) and [ Dockerfile-node ]( Dockerfile-node  )

The first thing we need to add is `# syntax=docker/dockerfile:experimental`.

Next, let's make use of the new `mount=type=cache` feature.

### mount=type=cache

For package managers, like APK or APT you have to do some extra work, since distributions made their dockers in way not to cache packages and here we want the opposite now.

For APT:
```dockerfile
# syntax = docker/dockerfile:experimental
FROM ubuntu
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt \
  apt update && apt install -y gcc
```

for APK:
```dockerfile
# syntax = docker/dockerfile:experimental
FROM alpine
RUN --mount=type=cache,target=/var/cache/apk ln -vs /var/cache/apk /etc/apk/cache && \
	apk add --update \
```

For NPM:
```dockerfile
RUN --mount=type=cache,id=npm,target=/root/.npm \
	npm install hello-world-npm
```

For NPM:
```dockerfile
# syntax = docker/dockerfile:experimental
FROM node:alpine AS node-builder
RUN --mount=type=cache,id=npm,target=/root/.npm \
	npm install hello-world-npm
```

```dockerfile
# syntax = docker/dockerfile:experimental
FROM golang
...
RUN --mount=type=cache,target=/root/.cache/go-build go build ...
```

For composer:
```dockerfile
# syntax = docker/dockerfile:experimental
FROM composer
RUN --mount=type=cache,id=composertarget=/root/.composer \
	composer -v install --no-dev --no-interaction
```

For Python3:
```dockerfile
# syntax = docker/dockerfile:experimental
FROM python:3.6-alpine
RUN --mount=type=cache,id=piptarget=/root/.cache/pip \
	pip install --find-links /src/ -r /src/requirements.pip
```

For Gradle:
```dockerfile
# syntax = docker/dockerfile:experimental
FROM gradle:jdk8-alpine
RUN --mount=type=cache,id=gradle,target=/root/.gradle \
	--mount=type=cache,id=gradle,target=/home/gradle/.gradle \
	gradle assemble --no-daemon --warning-mode all --info
```

For maven:
```dockerfile
# syntax = docker/dockerfile:experimental
FROM maven:jdk-8-alpine
RUN --mount=type=cache,id=maven,target=/root/.m2 \
	mvn install -Dspring.profiles.active=$RELEASE
```

#### id
We use `id=XXX` to keep cache of the same nature together.

#### sharing
It is also recommended to use `sharing=locked` or `sharing=private` if your package manager isn't able to deal with concurrent access to shared cache.

One will make the build process slightly slower, since the run commands that use the mount with same id will now wait for each other, and the other loses the benefit of shared cache.

.

### RUN --mount=type=secret

The official docs have a good example of how to manage secrets
https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/experimental.md#run---mounttypesecret


## buildx bake

`bake` is very basic, asking only for `--file FILE`, which can be one or multiple Docker Compose, JSON or HCL files.

You can use `--print` to see the resulting options of the targets desired to be built, in a JSON format, without starting a build.



So, using our example docker-compose and our new override, a build command looks like:
```sh
docker-buildx bake --progress plain -f docker-compose.yml -f buildx.yml
```

### Gotchas
* bake doesn't support push to a registry, so we have to use docker-compose for that

---

# Bibliography

## BuildKit
* https://github.com/moby/buildkit
* https://github.com/moby/moby/issues/34227
* https://blog.mobyproject.org/introducing-buildkit-17e056cc5317?gi=6dae90df2584
* https://docs.docker.com/develop/develop-images/build_enhancements/

## Buildx
* https://github.com/docker/buildx/blob/master/README.md

## Dockerfile frontend experimental syntaxes
* https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/experimental.md
