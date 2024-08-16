##
## Build
##
FROM golang:1.21-bullseye as base

## No password, home directory, login shell
RUN adduser \
  --disabled-password \
  --gecos "" \
  --home "/nonexistent" \
  --shell "/sbin/nologin" \
  --no-create-home \
  --uid 65532 \
  small-user

WORKDIR $GOPATH/src/app/

# Copy go.mod and go.sum files first
# This way, if only the source code changes, Docker can reuse the cache from previous builds.
COPY go.mod ./

# Download and verify dependencies
RUN go mod download
RUN go mod verify

# Copy the rest of the source code
COPY . .

# Build application
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /build/main .

##
## Deploy
##
FROM scratch

# Copy timezone data, ssl certs, passwd, and group files which is needed to function properly in container.
COPY --from=base /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=base /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=base /etc/passwd /etc/passwd
COPY --from=base /etc/group /etc/group

WORKDIR build
# Copy binary /main
COPY --from=base /build/main ./build/main

# Switch to the previous created user
USER small-user:small-user

# Run binary
CMD ["./build/main"]
