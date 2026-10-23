# Security

## Supported versions

Only the latest release gets fixes. If you are on an older one, update first
(System, About, Updates) and check the problem is still there.

| Version | Supported |
|---|---|
| Latest release | Yes |
| Latest prerelease, while it is newer than the latest release | Yes |
| Anything older | No |

## Reporting a problem

Please do not open a public issue for a security problem. Report it privately
through GitHub instead: the Security tab of this repository, then Report a
vulnerability. Only I can see it there until a fix is out.

Tell me what it is, the steps to reproduce it, the CyberUI and KOReader
versions and the device.

I will answer within a week. Once it is fixed I will put out a release, say
what was fixed in the changelog and credit you unless you would rather not be
named.

## What counts

CyberUI runs inside KOReader with the same rights KOReader has on your device,
so these matter most:

- **The updater and installer.** They only talk to GitHub, only install a
  release whose zip matches the SHA-256 digest GitHub lists for it, only
  unpack plain files inside the plugin's own folder, and check that every Lua
  file loads before anything is put in place. A way around any of that is a
  security problem.
- **Files it changes.** Rename, move and the trash change your books and
  their reading data. Anything that makes CyberUI change, move or delete
  files you did not ask it to is a security problem.

A crash or a slowdown is a normal bug; please report that as an issue.
Problems in KOReader itself belong to the
[KOReader project](https://github.com/koreader/koreader/security).
