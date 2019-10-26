FROM kong:1.4.0-alpine

LABEL description="Alpine + Kong 1.4.0 + kong-oidc plugin"

RUN apk update && apk add git unzip luarocks
RUN luarocks install kong-oidc
