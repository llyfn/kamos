FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# Build both binaries in the same stage so docker-compose can reuse a
# single image: `command: server` or `command: worker`. The default
# ENTRYPOINT below points at the server for backwards compatibility.
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server ./cmd/server
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/worker ./cmd/worker

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata && adduser -D -u 10001 kamos
USER kamos
COPY --from=build /out/server /usr/local/bin/server
COPY --from=build /out/worker /usr/local/bin/worker
# Preserve the historical entrypoint name so existing deployment configs
# continue to work — the binary at /usr/local/bin/kamos-api is the server.
COPY --from=build /out/server /usr/local/bin/kamos-api
EXPOSE 8080 9091
# Use CMD (not ENTRYPOINT) so docker-compose `command:` and Fly `[processes]`
# can fully override the launched binary. ENTRYPOINT would be prepended,
# turning `command: ["/usr/local/bin/worker"]` into
# `/usr/local/bin/server /usr/local/bin/worker` (server with stray arg).
CMD ["/usr/local/bin/server"]
