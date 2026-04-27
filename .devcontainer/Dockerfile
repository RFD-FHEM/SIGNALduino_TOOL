# syntax=docker/dockerfile:1@sha256:9857836c9ee4268391bb5b09f9f157f3c91bb15821bb77969642813b0d00518d

FROM ghcr.io/fhem/fhem-docker:5-bookworm AS main-app

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        gcc \
        g++ \
        && \
    rm -rf /var/lib/apt/lists/*

COPY cpanfile /usr/src/app/devcontainer/cpanfile

RUN cpm install --cpanfile /usr/src/app/devcontainer/cpanfile --without-test --with-suggests --with-recommends --show-build-log-on-failure --configure-timeout=360 --workers=$(nproc) --local-lib-contained /usr/src/app/devcontainer

ENV PERL5LIB=${PERL5LIB}:/usr/src/app/devcontainer/lib/perl5:/usr/src/RFFHEM/lib:/opt/fhem

EXPOSE 8083

HEALTHCHECK NONE

WORKDIR /usr/src/SIGNALduino_TOOL
