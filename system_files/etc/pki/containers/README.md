# Cosign verification keys

Keys in this directory are referenced by `/etc/containers/policy.json`.

- `cloudws-cosign.pub` - CloudWS-bootc signing key (placeholder; replace with
  your cosign keyless identity's cert once published, OR switch policy.json to
  use `fulcio.url`/`rekorURL` with keyless verification).
- `ublue-cosign.pub`   - Universal Blue signing key (fetched from
  https://github.com/ublue-os/main/raw/main/cosign.pub at build time by
  `scripts/42-cosign-policy.sh`).

If a key is missing and policy.json references it, `bootc switch`/`podman pull`
will fail closed. To bootstrap without signing, edit policy.json to replace the
sigstoreSigned entry with `insecureAcceptAnything` temporarily.