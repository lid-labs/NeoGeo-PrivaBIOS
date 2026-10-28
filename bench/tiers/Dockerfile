# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Thibaut Lion
# Chaîne de construction des BIOS Neo Geo tiers, pour les passer au banc.
# Ubuntu natif (pas d'émulation) + le cross-compilateur m68k de Debian, dont les noms
# (m68k-linux-gnu-*) sont EXACTEMENT ceux que le CMakeLists de neogeo-bios attend.
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake gcc-m68k-linux-gnu binutils-m68k-linux-gnu libc6-dev-m68k-cross ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
