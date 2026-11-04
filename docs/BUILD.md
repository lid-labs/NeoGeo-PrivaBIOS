# Building PrivaBIOS

## Requirements

- Docker. The toolchain runs in a container; nothing is installed on the host.
- `python3` on the host (3.9 or later), for the final padding and byte swap.
- On an arm64 host (Apple Silicon), Docker must be able to run `linux/amd64` images (emulation):
  the ngdevkit toolchain is published for amd64 only.

## Build

```bash
./build/construire.sh src/c0 privabios.sp1
```

The first run builds the Docker image `privabios-build` from [`docker/Dockerfile`](../docker/Dockerfile).
Nothing is pulled from a private registry: the image is Ubuntu 22.04 plus the `ngdevkit-toolchain`
package (GNU binutils and GCC for `m68k-neogeo-elf`) from the public
[ngdevkit PPA](https://launchpad.net/~dciabrin/+archive/ubuntu/ngdevkit).

The output is a 131,072-byte image in MAME byte order (bytes swapped in pairs), the format of
`sp-s2.sp1` in MAME's `neogeo.zip`. Intermediate files go to `obj/` (set `BIOS_OBJ` to change it).

To get the other byte order, for a programmer set the other way round:

```bash
python3 -c 'import sys; d=open(sys.argv[1],"rb").read(); open(sys.argv[2],"wb").write(bytes(b for i in range(0,len(d),2) for b in (d[i+1],d[i])))' privabios.sp1 privabios-byteswapped.bin
```

## Reproducibility

The Dockerfile pins `ngdevkit-toolchain` to version `0.1+202602051135-14~ubuntu22.04.1` (GNU
assembler 2.44). With that version, the SHA-256 of the image built from the current sources is the
one in [`build/expected-sha256.txt`](../build/expected-sha256.txt); the CI builds the image and fails
if its SHA-256 differs. A change to the sources that changes the image updates that
file in the same commit.

Two builds of the same sources give the same bytes: the object order is sorted and nothing in the
image depends on the date or the path. If the PPA no longer serves the pinned version, build with
`docker build --build-arg NGDEVKIT_TOOLCHAIN= …` to take the current one; the image may then differ.

## Other outputs

- `build/harnais/` assembles a minimal image that only proves the toolchain and the link script.
- `diag/slots/` is a separate diagnostic image for multi-slot boards.
- `bench/tiers/construire.sh` builds the free third-party BIOSes (NeoPen, neogeo-bios) from their
  public repositories, at pinned commits, to compare them on the bench.

## The co-simulator

The contracts in [`specs/traces/`](../specs/traces/) were generated from bus traces of a
co-simulation (a Verilator model of a 68000 core and of the Neo Geo video chip). That co-simulator
is not published here. You do not need it to build the BIOS, nor to run the contract generator's
tests, which use synthetic traces:

```bash
python3 -I bench/test_generer_contrats.py
```

Regenerating the contracts from new traces does need it.

## Releases

A tag `vX.Y.Z` on `main` builds the image in CI and opens a draft GitHub release: see
[RELEASE.md](RELEASE.md).
