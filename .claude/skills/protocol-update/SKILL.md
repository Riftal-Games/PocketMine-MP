---
name: protocol-update
description: The pmmp-core side of a Bedrock protocol update. The update itself runs in pmmp-updater; this covers the core changes it needs, the submodule bump and the version tag. Use when pmmp-updater's /protocol-update reaches its core stage, or when someone asks to update this fork to a new Bedrock version.
when_to_use: A new Bedrock version is being brought in and pmmp-updater has produced its packages, or a session opened in pmmp-core is asked to update the protocol.
---

# Protocol update: the core side

The protocol libraries this fork runs on live in `Riftal-Games/pmmp-updater`, and so does the update procedure: `/protocol-update` there, from Mojang's first preview through docs diff, packet code, BDS data and upgrade schemas. No upstream maintainer is consulted (Nasir, 2026-11-01, `../docs/decision-log.md`).

If you were asked to update the protocol from here, open `../pmmp-updater` and run its `/protocol-update`. This skill is only for the steps that change this repository.

## 1. Branch

`bedrock-<version>`, cut from `riftal`. Never merge it before Mojang releases the version.

## 2. Point at the new packages

While the packages are still on pmmp-updater's `bedrock-<version>` branch, move the submodule to that branch's head:

```
git -C deps/pmmp-updater fetch origin bedrock-<version>
git -C deps/pmmp-updater checkout FETCH_HEAD
```

Then update `composer.json`:
- the four `options.versions` entries under `repositories`;
- the `require` constraints.

Run `composer update axolotl-pm/bedrock-block-upgrade-schema axolotl-pm/bedrock-data axolotl-pm/bedrock-item-upgrade-schema axolotl-pm/bedrock-protocol --ignore-platform-reqs --no-install` in a PHP container, never on the host.

## 3. Core changes (steward, `src/` is gated)

1. `src/data/bedrock/block` and `src/data/bedrock/item` for new or changed types, then `composer update-codegen`.
2. `src/data/bedrock/WorldDataVersions.php`: `LAST_OPENED_IN` and `NETWORK` every version, `BLOCK_STATES` often, `CHUNK`, `SUBCHUNK` and `STORAGE` rarely.
3. `vendor/bin/phpstan analyze` until clean, `vendor/bin/phpunit tests/phpunit` until green, in the PHP-stage container.
4. `.github/workflows/reachable-smoke.sh`: move `EXPECTED_PROTOCOL` to the new number, deliberately. That pin exists so a protocol change is never silent.

## 4. Verify

The image builds from the branch. The server reaches Done with every plugin and no exception. The pong advertises the new protocol. A bot scenario passes once the bots speak the version. A real client on this PC joins, breaks and places a block, and rejoins after a restart with no upgrade errors.

## 5. Merge and tag

Once Mojang has released the version and pmmp-updater has tagged `v<version>`:
1. Move the submodule to that tag.
2. Bump `BASE_VERSION` in `src/VersionInfo.php` by a **minor** step.
3. Open the PR from `bedrock-<version>` to `riftal`, for the steward to merge. Merge, never rebase.
4. Run `/diff-audit` before tagging the release.

## Rules

Nothing here is a reason to add game logic. A protocol change that tempts you to implement a vanilla mechanic goes to the design plan first.
