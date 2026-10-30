## What this changes

<!-- What the player or operator will notice, and why. -->

## Checklist

- [ ] **Clean room.** I have never read, disassembled, decompiled, stepped through in a debugger or
      copied the code or ROM bytes of the SNK BIOS, of UniBIOS, of another third-party BIOS or of a
      game; I have only observed them running. I have used no third-party cheat database. This
      change contains no byte of their ROMs
      ([CONTRIBUTING.md](../CONTRIBUTING.md#clean-room-rules)).
- [ ] **Scene and mutation.** Each visible change has a scene in `bench/parcours.sh` and a mutation in
      `bench/parcours-mutations.py` that the scene catches (or this change is not visible to the
      player: explain below).
- [ ] **Regression.** `bench/non-regression.sh` passed locally with my own ROM sets.
- [ ] **Changelog.** `CHANGELOG.md` has a line under `Unreleased`, if a user can notice the change.
- [ ] My commits are signed off (`git commit -s`).

## Notes

<!-- Deliberate differences from the original BIOS, measurements, anything the reviewer should know. -->
