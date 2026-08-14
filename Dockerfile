# Two stages: compile Gleam to JavaScript, then run it on Node alone.
#
# The runtime image has no Gleam and no Erlang — the JS target means the
# compiler is a build-time tool only, which is also why this image is small.

FROM node:22-alpine AS build

ARG GLEAM_VERSION=1.18.1
RUN apk add --no-cache curl \
 && curl -fsSL -o /tmp/gleam.tar.gz \
      "https://github.com/gleam-lang/gleam/releases/download/v${GLEAM_VERSION}/gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
 && tar xzf /tmp/gleam.tar.gz -C /usr/local/bin gleam \
 && rm /tmp/gleam.tar.gz

WORKDIR /app
# Manifest first so dependency resolution is cached independently of sources.
COPY gleam.toml manifest.toml ./
RUN gleam deps download

COPY src ./src
COPY test ./test
RUN gleam build

# Tailwind scans src/**/*.gleam for class names, so this must run after the
# sources are in place. app.css is a build artifact and is gitignored, so the
# image builds it rather than shipping a copy that could disagree.
COPY assets ./assets
# priv/ carries the static images; Tailwind writes app.css alongside them, so
# both reach the runtime stage through a single copy of this directory.
COPY priv ./priv
RUN cd assets \
 && npm ci --no-audit --no-fund 2>/dev/null || npm install --no-audit --no-fund \
 && npm run build

FROM node:22-alpine AS runtime

# Run as a non-root user. Nothing here needs to write to the filesystem.
RUN addgroup -S sonic && adduser -S -G sonic sonic
WORKDIR /app
COPY --from=build --chown=sonic:sonic /app/build/dev/javascript ./javascript
COPY --from=build --chown=sonic:sonic /app/priv ./priv
COPY --chown=sonic:sonic bin ./bin
# The browser entry sits beside the compiled modules so its relative imports
# resolve; it is kept out of the Gleam build so its path does not carry the
# compiler version.
COPY --chown=sonic:sonic bin/client_entry.mjs ./javascript/sonic/client_entry.mjs
USER sonic

# Must be 0.0.0.0, not loopback: Traefik reaches this container over the docker
# network, so a loopback bind here yields a healthy container, a live router,
# and a uniform 502. Keeping the port off the *host* is a separate concern,
# handled by `nomad_host_network: loopback` in ginger.yml.
ENV SONIC_HOST=0.0.0.0
# Compiled modules live at /app/javascript in the runtime image, not at the
# build tree's path.
ENV SONIC_JS_ROOT=javascript
EXPOSE 3000

CMD ["node", "bin/server.mjs"]
