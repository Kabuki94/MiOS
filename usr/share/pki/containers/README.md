<!-- [NET] MiOS Artifact | Proprietor: MiOS-DEV | https://github.com/Kabuki94/MiOS-bootstrap -->
# [NET] MiOS
```json:knowledge
{
  "summary": "> **Proprietor:** MiOS-DEV",
  "logic_type": "documentation",
  "tags": [
    "MiOS",
    "usr"
  ],
  "relations": {
    "depends_on": [
      ".env.mios"
    ],
    "impacts": []
  }
}
```
> **Proprietor:** MiOS-DEV
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to MiOS-DEV
---
# Cosign verification keys

Keys in this directory are referenced by `/etc/containers/policy.json`.

- `mios-cosign.pub` - MiOS signing key (placeholder; replace with
  your cosign keyless identity's cert once published, OR switch policy.json to
  use `fulcio.url`/`rekorURL` with keyless verification).
- `ublue-cosign.pub`   - Universal Blue signing key (fetched from
  https://github.com/ublue-os/main/raw/main/cosign.pub at build time by
  `automation/42-cosign-policy.sh`).

If a key is missing and policy.json references it, `bootc switch`/`podman pull`
will fail closed. To bootstrap without signing, edit policy.json to replace the
sigstoreSigned entry with `insecureAcceptAnything` temporarily.

---
###  Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osautomation/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/MiOS-bootstrap](https://github.com/Kabuki94/MiOS-bootstrap)
- **Sole Proprietor:** MiOS-DEV
---
<!--  MiOS Proprietary Artifact | Copyright (c) 2026 MiOS-DEV -->
