FROM alpine:3.22

RUN apk add --no-cache dnsmasq

# Authoritative only for the --address domains passed as the command.
# --no-resolv: never forward other names upstream.
ENTRYPOINT ["dnsmasq", "--keep-in-foreground", "--no-resolv", "--no-hosts", "--log-facility=-"]
