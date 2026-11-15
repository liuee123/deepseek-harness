# Docker from local source

English | [中文](README.zh.md)

## Summary

Build a Linux image from this checkout and run the Web UI with a shared Chromium desktop. The builder installs third-party dependencies and system packages from their registries; it compiles DSH and its Browser Use providers from this workspace instead of installing published DSH packages.

## Table of contents

- [Build and start](#build-and-start)
- [Data and ports](#data-and-ports)
- [Build and verification](#build-and-verification)
- [Dev note](#dev-note)

<a id="build-and-start"></a>

## Build and start

Install Docker with Linux container support and the Compose plugin, Node.js 24.9 or newer, Git, and the pnpm version declared in the root package manifest. Run these commands in the repository root:

```sh
pnpm docker:build
pnpm docker:up
```

Open the [Web UI](http://127.0.0.1:3080) and the [Chromium desktop](http://127.0.0.1:6080/vnc.html). The configuration-file editor opens in that desktop. Use the Web UI's authentication flow and configure the model provider before sending a task.

```sh
pnpm docker:logs
pnpm docker:down
```

Rebuild after source changes, then replace the running container:

```sh
pnpm docker:build
node docker/compose.mjs up --detach --no-build --pull never --force-recreate
```

The wrapper reads the source version and Git revision for the build. For a checkout without Git metadata, supply a known source commit through `DSH_CLIENT_COMMIT_HASH`. Docker still needs network access for the base image, OS packages and third-party dependencies.

<a id="data-and-ports"></a>

## Data and ports

The Compose project is named `deepseek-harness-source`; it uses separate named volumes from the community image deployment. `/home/node/.dsh` stores DSH state and the browser profile; `/workspace` stores working files. Stopping or recreating the container preserves those volumes. `docker compose down --volumes` removes the project's named volumes.

Set `DSH_WORKSPACE` to an absolute host directory to use a bind-mounted workspace, and make it writable by container UID 1000. Ports bind to host loopback. Set `DSH_PORT` and `DSH_DESKTOP_PORT` in the host environment or root `.env` to change their default values of 3080 and 6080; an existing deployment using those ports must be stopped or assigned different ports.

The root filesystem is read-only, with writable volumes and `/tmp`. Chromium runs with `--no-sandbox` under container restrictions. The noVNC desktop has no separate password; keep its host port on loopback. The container is a shared Agent environment rather than a multi-user isolation service. `unhealthy` does not itself restart the container.

<a id="build-and-verification"></a>

## Build and verification

The build uses the root package manager declaration and frozen dependency lockfile, then runs `build:artifacts` and `build:check`. Production deployment uses the repository's legacy pnpm deployment helpers and the populated dependency store. Only the builder's CLI manifest gains local Browser Use dependencies; the checked-in manifest and lockfile remain unchanged. The final image includes the deployed runtime, browser, desktop and container adapters; host `node_modules`, compiled outputs, Git data and environment files are excluded from the build context.

`DSH_BUILD_CONCURRENCY` sets the build scheduler's worker count, defaulting to 2. `DSH_IMAGE` selects the local image tag, defaulting to `deepseek-harness:local`. The community desktop plugin and adapters are copied under this directory with their license notices; they do not require the sibling Docker repository at build time.

```sh
pnpm docker:check
```

Path parsing and deployment metadata have local tests. Linux relay tests cover TCP forwarding; Windows cannot report the same POSIX signal result. During image construction, a separate check launches Xvfb, invokes `explorer.exe`, and waits for the configuration editor window. Compose checks the Web authentication response, noVNC page and Chromium debugging endpoint. Image construction and runtime checks require a Docker host; they have not been executed in the authoring environment.

<a id="dev-note"></a>

## Dev note

Container runtime changes belong to this directory and the root Dockerfile and Compose configuration. DSH application behavior remains owned by its source packages.
