FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/kamos-api ./cmd/server

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata && adduser -D -u 10001 kamos
USER kamos
COPY --from=build /out/kamos-api /usr/local/bin/kamos-api
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/kamos-api"]
