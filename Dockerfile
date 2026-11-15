# syntax=docker/dockerfile:1.7

ARG NODE_IMAGE=docker.io/library/node:24-trixie
FROM ${NODE_IMAGE} AS installer

ENV CI=true \
    ELECTRON_SKIP_BINARY_DOWNLOAD=1 \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
WORKDIR /src
RUN sed -i 's|http://deb.debian.org|https://deb.debian.org|g' /etc/apt/sources.list.d/debian.sources \
    && apt-get update \
    && apt-get install --yes --no-install-recommends build-essential ca-certificates python3 \
    && rm -rf /var/lib/apt/lists/*

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN npm install --global --no-audit --no-fund "$(node -p 'require("./package.json").packageManager')" \
    && npm cache clean --force
COPY . .

# Source metadata is supplied by docker/compose.mjs; host build outputs are excluded.
ARG DSH_CLIENT_COMMIT_HASH
ARG DSH_BUILD_CONCURRENCY=2
ENV DSH_GATE_CONCURRENCY=${DSH_BUILD_CONCURRENCY}
RUN test -n "${DSH_CLIENT_COMMIT_HASH}" || \
    { echo 'Use pnpm docker:build, or pass --build-arg DSH_CLIENT_COMMIT_HASH=<git-commit>' >&2; exit 1; }
RUN --mount=type=cache,target=/pnpm/store \
    pnpm install --frozen-lockfile --store-dir=/pnpm/store
RUN pnpm run build:artifacts \
    && pnpm run build:check
RUN --mount=type=cache,target=/pnpm/store \
    DSH_DOCKER_BUILD=1 PNPM_CONFIG_STORE_DIR=/pnpm/store node docker/deploy.mjs

FROM ${NODE_IMAGE}

ARG NODE_IMAGE
ARG CHROMIUM_FLAVOR=debian
ARG UNGOOGLED_CHROMIUM_VERSION=152.0.7977.82-1
ARG UNGOOGLED_CHROMIUM_AMD64_SHA256=2c6e464e030f87145e42553c5aa539f6e62163ce677d3eace3c51b4fcbd5e347
ARG UNGOOGLED_CHROMIUM_ARM64_SHA256=1909f42dcc3661bc213f2cf3b5232a9d3c850913b36efa7267ed6499f6cbf87d
ARG TARGETARCH

# Use Node's official non-slim Trixie variant intentionally: its buildpack-deps
# base provides the compiler and common development utilities a coding agent or
# native plugin may need at runtime, while glibc 2.41 accepts newer binaries
# than Bookworm's glibc 2.36. Install the remaining user-facing CLI tools
# explicitly so their availability is covered by the smoke test. The default
# flavor installs Chromium from Debian. The separately tagged ungoogled flavor
# uses a checksum-pinned portable build and still runs natively on amd64/arm64.
# Noto CJK keeps Chinese pages and screenshots readable.
RUN set -eux; \
    case "${CHROMIUM_FLAVOR}" in \
      debian|ungoogled) ;; \
      *) echo "unsupported Chromium flavor: ${CHROMIUM_FLAVOR}" >&2; exit 1 ;; \
    esac; \
    sed -i 's|http://deb.debian.org|https://deb.debian.org|g' /etc/apt/sources.list.d/debian.sources; \
    apt-get update; \
    apt-get install --yes --no-install-recommends \
      ca-certificates \
      curl \
      file \
      fonts-liberation \
      fonts-noto-cjk \
      git \
      jq \
      less \
      novnc \
      openbox \
      openssh-client \
      procps \
      python3 \
      ripgrep \
      rsync \
      tini \
      tk \
      unzip \
      websockify \
      wget \
      x11-utils \
      x11vnc \
      xterm \
      xvfb \
      zip; \
    if [ "${CHROMIUM_FLAVOR}" = debian ]; then \
      apt-get install --yes --no-install-recommends chromium; \
    else \
      case "${TARGETARCH}" in \
        amd64) \
          ungoogled_arch=x86_64; \
          ungoogled_sha256="${UNGOOGLED_CHROMIUM_AMD64_SHA256}"; \
          ;; \
        arm64) \
          ungoogled_arch=arm64; \
          ungoogled_sha256="${UNGOOGLED_CHROMIUM_ARM64_SHA256}"; \
          ;; \
        *) echo "unsupported architecture for ungoogled-chromium: ${TARGETARCH}" >&2; exit 1 ;; \
      esac; \
      ungoogled_archive="ungoogled-chromium-${UNGOOGLED_CHROMIUM_VERSION}-${ungoogled_arch}_linux.tar.xz"; \
      ungoogled_url="https://github.com/ungoogled-software/ungoogled-chromium-portablelinux/releases/download/${UNGOOGLED_CHROMIUM_VERSION}/${ungoogled_archive}"; \
      curl --fail --location --retry 3 --output "/tmp/${ungoogled_archive}" "${ungoogled_url}"; \
      printf '%s  %s\n' "${ungoogled_sha256}" "/tmp/${ungoogled_archive}" | sha256sum --check --strict -; \
      mkdir -p /opt/ungoogled-chromium; \
      tar --extract --xz --file "/tmp/${ungoogled_archive}" \
        --directory /opt/ungoogled-chromium --strip-components=1; \
      ln -s /opt/ungoogled-chromium/chrome-wrapper /usr/bin/chromium; \
      rm -f "/tmp/${ungoogled_archive}"; \
    fi; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /usr/local/lib/node_modules/@deepseek-ai

# The portable archive contains Chromium itself, but intentionally does not
# bundle the Debian shared libraries it links against. Keep these packages in
# a separate layer so changing the dependency set does not invalidate the much
# larger, checksum-verified browser download above.
RUN if [ "${CHROMIUM_FLAVOR}" = ungoogled ]; then \
      apt-get update; \
      apt-get install --yes --no-install-recommends \
        libasound2t64 \
        libatk-bridge2.0-0t64 \
        libatk1.0-0t64 \
        libatspi2.0-0t64 \
        libcairo2 \
        libdav1d7 \
        libdouble-conversion3 \
        libflac14 \
        libglib2.0-0t64 \
        libharfbuzz-subset0 \
        libharfbuzz0b \
        libjpeg62-turbo \
        liblcms2-2 \
        libminizip1t64 \
        libmp3lame0 \
        libmpg123-0t64 \
        libnspr4 \
        libnss3 \
        libogg0 \
        libopenh264-8 \
        libopenjp2-7 \
        libopus0 \
        libpango-1.0-0 \
        libpulse0 \
        libvorbis0a \
        libvorbisenc2 \
        libx11-6 \
        libxcb1 \
        libxext6 \
        libxkbcommon0 \
        libxnvctrl0; \
      rm -rf /var/lib/apt/lists/*; \
      ! ldd /opt/ungoogled-chromium/chrome | grep -F 'not found'; \
    fi

# Keep the distro-provided root for backward-compatible direct links, while
# giving the embedded client an immutable path. This prevents a browser from
# combining an upgraded rfb.js with an older cached util/browser.js.
ARG NOVNC_ASSET_REVISION=debian-1.6.0-2
RUN novnc_copy="$(mktemp -d)" \
    && cp -a /usr/share/novnc/. "${novnc_copy}/" \
    && mkdir -p "/usr/share/novnc/novnc-${NOVNC_ASSET_REVISION}" \
    && cp -a "${novnc_copy}/." "/usr/share/novnc/novnc-${NOVNC_ASSET_REVISION}/" \
    && rm -rf "${novnc_copy}"

# dsh misdetects Docker Desktop's WSL2 kernel as WSL and spawns
# wslpath/powershell.exe/explorer.exe (absent in the container) to open native
# paths. Fake wslpath echoes the target path; the opener shims use the editor
# on the VNC display (:99, viewable through noVNC), so "Open configuration
# file" and host.openPath open the editor instead of failing with ENOENT.
RUN cat > /usr/local/bin/wslpath <<'SHIM'
#!/bin/sh
# Fake wslpath: dsh calls `wslpath -w <path>`; echo the path unchanged.
out=""
for arg in "$@"; do
  case "$arg" in
    -w|-u|-m|--*) ;;
    *) out="$arg" ;;
  esac
done
printf '%s\n' "${out:-/}"
exit 0
SHIM
RUN cat > /usr/local/bin/powershell.exe <<'SHIM'
#!/bin/sh
# Fake powershell.exe: dsh runs
#   powershell.exe -NoProfile -Command "Invoke-Item -LiteralPath '<path>'"
# Extract the path and open it with wish on the VNC desktop, then exit 0 so
# dsh reports the open as successful.
command_text=""
for arg in "$@"; do
  case "$arg" in
    -NoProfile|-Command) ;;
    *) command_text="$arg" ;;
  esac
done
path=""
if [ -n "$command_text" ]; then
  path=$(printf '%s' "$command_text" \
    | sed -n "s/.*-LiteralPath[[:space:]]*'\([^']*\)'[[:space:]]*$/\1/p" \
    | sed "s/''/'/g")
fi
if [ -z "$path" ] || [ ! -e "$path" ]; then exit 0; fi
DISPLAY="${DISPLAY:-:99}" /usr/bin/wish /usr/local/bin/dsh-editor.tcl "$path" >/dev/null 2>&1 &
exit 0
SHIM
RUN cat > /usr/local/bin/dsh-editor.tcl <<'SHIM'
#!/usr/bin/wish
# VNC desktop mini editor, opened by the Windows opener shims.
# File mode: edit and Save (Ctrl+S). Directory mode: double-click to descend.
set target [lindex $argv 0]
if {$target eq ""} { exit }

if {[file isdirectory $target]} {
  wm title . "Pick: $target"
  wm geometry . 680x520
  listbox .lb -width 90 -height 30 -yscrollcommand {.vs set}
  scrollbar .vs -command {.lb yview}
  pack .lb -side left -fill both -expand true
  pack .vs -side right -fill y
  foreach f [lsort [glob -nocomplain -directory $target *]] {
    .lb insert end [file tail $f]
  }
  bind .lb <Double-Button-1> {
    set sel [lindex [.lb curselection] 0]
    if {$sel ne ""} {
      exec wish [info script] [file join $target [.lb get $sel]] &
    }
  }
  return
}

wm title . "Edit: $target"
wm geometry . 900x640
frame .bar
button .bar.save -text "Save (Ctrl+S)" -command saveFile
button .bar.close -text "Close (Ctrl+W)" -command exit
label .bar.path -text $target -anchor w
pack .bar.save .bar.close -side left -padx 3 -pady 3
pack .bar.path -side left -fill x -expand true -padx 6
pack .bar -side top -fill x

text .txt -wrap word -undo true -yscrollcommand {.vs set} -font {TkFixedFont 11}
scrollbar .vs -command {.txt yview}
pack .txt -side left -fill both -expand true
pack .vs -side right -fill y

if {[catch {set fd [open $target r]; fconfigure $fd -encoding utf-8; set content [read $fd]; close $fd} err]} {
  tk_messageBox -message "Open failed: $err" -type ok -icon warning
  exit
}
.txt insert 1.0 $content
focus .txt

proc saveFile {} {
  global target
  if {[catch {
    set fd [open $target w]
    fconfigure $fd -encoding utf-8
    puts -nonewline $fd [.txt get 1.0 end-1c]
    close $fd
  } err]} {
    tk_messageBox -message "Save failed: $err" -type ok -icon error
    return
  }
  .bar.save configure -text "Saved ✓"
  after 1200 { .bar.save configure -text "Save (Ctrl+S)" }
}
bind .txt <Control-s> saveFile
bind .txt <Control-w> exit
bind . <Control-s> saveFile
bind . <Control-w> exit
SHIM
COPY docker/dsh-explorer.cjs /usr/local/bin/explorer.exe
RUN sed -i 's/\r$//' /usr/local/bin/explorer.exe \
    && chmod 0755 /usr/local/bin/wslpath /usr/local/bin/powershell.exe \
      /usr/local/bin/explorer.exe /usr/local/bin/dsh-editor.tcl

# Exercise the exact executable lookup and wait for a real Tk editor window.
# The test is mounted only for this build step and is not shipped in the image.
RUN --mount=type=bind,source=docker/dsh-explorer.test.cjs,target=/tmp/dsh-explorer.test.cjs \
    DSH_EXPLORER_MODULE=/usr/local/bin/explorer.exe DSH_EXPLORER_SMOKE=1 \
    node --test /tmp/dsh-explorer.test.cjs

COPY --from=installer /opt/dsh-runtime /usr/local/lib/node_modules/@deepseek-ai/dsh
COPY --from=installer /usr/local/lib/node_modules/pnpm /usr/local/lib/node_modules/pnpm
COPY docker/chromium-docker /usr/local/bin/chromium-docker
COPY docker/dsh-container /usr/local/bin/dsh
COPY docker/deepseek-harness-entrypoint /usr/local/bin/deepseek-harness-entrypoint
COPY docker/dsh-web-relay.cjs /opt/deepseek-harness/dsh-web-relay.cjs
COPY docker/plugins/dsh-browser-desktop /opt/deepseek-harness/plugins/dsh-browser-desktop

# Normalize executable scripts copied from Windows checkouts before running them.
RUN sed -i 's/\r$//' /usr/local/bin/chromium-docker /usr/local/bin/dsh \
        /usr/local/bin/deepseek-harness-entrypoint \
    && chmod 0755 /usr/local/bin/chromium-docker \
        /usr/local/bin/dsh \
        /usr/local/bin/deepseek-harness-entrypoint \
    && mkdir -p \
      /usr/local/lib/node_modules/@deepseek-ai/dsh/node_modules/@runzhliu \
      /opt/deepseek-harness/plugins/dsh-browser-desktop/node_modules/@deepseek-ai \
    && ln -s /opt/deepseek-harness/plugins/dsh-browser-desktop \
      /usr/local/lib/node_modules/@deepseek-ai/dsh/node_modules/@runzhliu/dsh-browser-desktop \
    && ln -s /usr/local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/schemastery \
      /opt/deepseek-harness/plugins/dsh-browser-desktop/node_modules/@deepseek-ai/schemastery \
    && ln -s "../lib/node_modules/pnpm/$(node -p 'require("/usr/local/lib/node_modules/pnpm/package.json").bin.pnpm')" /usr/local/bin/pnpm \
    && ln -s "../lib/node_modules/pnpm/$(node -p 'require("/usr/local/lib/node_modules/pnpm/package.json").bin.pnpx')" /usr/local/bin/pnpx \
    && ln -s chromium-docker /usr/local/bin/chrome \
    && ln -s chromium-docker /usr/local/bin/google-chrome \
    && ln -s chromium-docker /usr/local/bin/google-chrome-stable \
    && if [ ! -e /usr/share/novnc/index.html ]; then \
      ln -s vnc.html /usr/share/novnc/index.html; \
    fi \
    && test "$(dsh --version)" = "$(node -p 'require("/usr/local/lib/node_modules/@deepseek-ai/dsh/package.json").version')" \
    && test "$(pnpm --version)" = "$(node -p 'require("/usr/local/lib/node_modules/pnpm/package.json").version')" \
    && test "$(node -p 'require("/usr/local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-browser-use/package.json").version')" = "$(node -p 'require("/usr/local/lib/node_modules/@deepseek-ai/dsh/package.json").version')" \
    && test "$(node -p 'require("/usr/local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-experimental-browser-use-playwright-mcp/package.json").version')" = "$(node -p 'require("/usr/local/lib/node_modules/@deepseek-ai/dsh/package.json").version')" \
    && node -e "Promise.all([import('/usr/local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-browser-use/lib/index.js'), import('/usr/local/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-experimental-browser-use-playwright-mcp/lib/index.js')])" \
    && chromium-docker --version

ENV DSH_HOME=/home/node/.dsh \
    DSH_TELEMETRY_DISABLED=1 \
    DSH_NOVNC_ASSET_REVISION=${NOVNC_ASSET_REVISION} \
    CHROMIUM_FLAVOR=${CHROMIUM_FLAVOR} \
    HOME=/workspace \
    NPM_CONFIG_CACHE=/home/node/.dsh/npm-cache \
    DISPLAY=:99 \
    XDG_RUNTIME_DIR=/tmp/runtime-node \
    CHROME_BIN=/usr/local/bin/chromium-docker \
    CHROME_PATH=/usr/local/bin/chromium-docker \
    BROWSER=/usr/local/bin/chromium-docker \
    PUPPETEER_EXECUTABLE_PATH=/usr/local/bin/chromium-docker \
    XDG_CACHE_HOME=/tmp/.cache \
    XDG_CONFIG_HOME=/tmp/.config \
    XDG_DATA_HOME=/tmp/.local/share

COPY --chown=node:node docker/web.cordis.patch.yml /opt/deepseek-harness/web.cordis.patch.yml

RUN mkdir -p "${DSH_HOME}" /workspace \
    && chown -R node:node "${DSH_HOME}" /workspace

USER node
WORKDIR /workspace

EXPOSE 3080 6080

# Keep source metadata after every filesystem-producing instruction so a new
# commit revision updates only image configuration instead of invalidating the
# large Debian/Chromium installation layers.
ARG IMAGE_VERSION=local
ARG IMAGE_REVISION=unknown
LABEL org.opencontainers.image.title="DeepSeek Harness (Local Source)" \
      org.opencontainers.image.description="DeepSeek Harness built from the local workspace with Web UI and a Chromium desktop" \
      org.opencontainers.image.source="https://github.com/deepseek-ai/deepseek-harness" \
      org.opencontainers.image.url="https://github.com/deepseek-ai/deepseek-harness" \
      org.opencontainers.image.documentation="https://github.com/deepseek-ai/deepseek-harness" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      io.github.runzhliu.deepseek-harness.base-image="${NODE_IMAGE}" \
      io.github.runzhliu.deepseek-harness.debian-codename="trixie" \
      io.github.runzhliu.deepseek-harness.chromium.flavor="${CHROMIUM_FLAVOR}" \
      io.github.runzhliu.deepseek-harness.chromium.ungoogled.version="${UNGOOGLED_CHROMIUM_VERSION}" \
      io.github.runzhliu.deepseek-harness.browser-use.provider="playwright-mcp" \
      io.github.runzhliu.deepseek-harness.browser-use.mode="attach" \
      io.github.runzhliu.deepseek-harness.upstream.repository="https://github.com/deepseek-ai/deepseek-harness" \
      io.github.runzhliu.deepseek-harness.build-input="local-workspace"

# The CLI mounts a config-only HMR watcher after profile boot. Scope Node's
# internal-module access flag to the dsh process instead of exporting it via
# NODE_OPTIONS to every child process the agent starts.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/deepseek-harness-entrypoint"]
CMD ["web", "--patch", "/opt/deepseek-harness/web.cordis.patch.yml", "--no-open"]
