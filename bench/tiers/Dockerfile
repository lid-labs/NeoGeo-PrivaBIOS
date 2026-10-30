# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# Build toolchain for the third-party Neo Geo BIOSes, to put them through the bench.
# Native Ubuntu (no emulation) + Debian's m68k cross-compiler, whose names
# (m68k-linux-gnu-*) are EXACTLY the ones neogeo-bios's CMakeLists expects.
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake gcc-m68k-linux-gnu binutils-m68k-linux-gnu libc6-dev-m68k-cross ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
