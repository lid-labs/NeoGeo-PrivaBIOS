# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
#
# Build environment for PrivaBIOS: the m68k-neogeo-elf toolchain (binutils + gcc) from the
# public ngdevkit PPA (https://launchpad.net/~dciabrin/+archive/ubuntu/ngdevkit), on Ubuntu 22.04.
# Nothing else is installed, and nothing from this repository is copied into the image.
#
# The PPA publishes amd64 packages only, hence the pinned platform (emulated on arm64 hosts).
#
# NGDEVKIT_TOOLCHAIN pins the toolchain package version that produced the reference image
# (see docs/BUILD.md). Set it to an empty string to take whatever the PPA currently serves; the
# resulting image may then differ byte for byte.
#
#   docker build --platform linux/amd64 -t privabios-build docker/
FROM --platform=linux/amd64 ubuntu:22.04

ARG NGDEVKIT_TOOLCHAIN=0.1+202602051135-14~ubuntu22.04.1
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       software-properties-common ca-certificates gnupg bash coreutils \
  && add-apt-repository -y ppa:dciabrin/ngdevkit \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
       "ngdevkit-toolchain${NGDEVKIT_TOOLCHAIN:+=$NGDEVKIT_TOOLCHAIN}" \
  && rm -rf /var/lib/apt/lists/*
