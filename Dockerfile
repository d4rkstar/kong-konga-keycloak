FROM kong:1.1.1-alpine

LABEL description="Alpine + Kong 1.1.1 + kong-oidc plugin"

RUN apk update && apk add git unzip luarocks

RUN luarocks install kong-oidc