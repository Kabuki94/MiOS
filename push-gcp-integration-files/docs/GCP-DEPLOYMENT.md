# CloudWS-bootc on Google Cloud Platform

## 1. Architecture at a glance

CloudWS-bootc runs on GCP in three complementary shapes from a single OCI
artifact hosted in Google Artifact Registry (GAR):

| Target | Form | Best for |
|---|---|---|
| **Google Compute Engine** | custom OS image from `bootc-image-builder --type gce` | persistent workstations, GPU VMs, long-lived VDI hosts |
| **Google Cloud Workstations** | same image consumed as a *container* | ephemeral developer VDI with IDE integration |
| **Google Kubernetes Engine** | container Pod (lightweight) or KubeVirt VM (full) | fleet of disposable Kasm-style sessions, or VM workloads |

Both access topologies ship in every shape:

- **Headless SSH + Cockpit** on loopback, IAP-tunneled on port 9090.
- **Browser-native VDI** via Apache Guacamole + KasmVNC behind nginx, fronted
  by an HTTPS Load Balancer with Identity-Aware Proxy (IAP).

All pulls from GAR use short-lived OAuth2 tokens minted from the instance's
attached service account via the metadata server — no static keys.

## 2. Build pipeline (bootc-image-builder → GCE image)

`bootc-image-builder` 2025-Q4+ supports `--type gce` natively. It emits
`output/gce/image.tar.gz` containing a `disk.raw` file in the oldgnu sparse
tarball format GCE demands. The canonical invocation lives in
`.github/workflows/build-gcp-artifact.yml` and mirrors:

```bash
sudo podman run --rm --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  -v ./bib-configs/gcp.toml:/config.toml:ro \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type gce --rootfs xfs --config /config.toml \
  ghcr.io/kabuki94/cloudws-bootc:latest
```

Upload and register:

```bash
gcloud storage cp output/gce/image.tar.gz \
  gs://$BUCKET/cloudws-$TAG/disk.raw.tar.gz
gcloud compute images create cloudws-bootc-$TAG \
  --source-uri=gs://$BUCKET/cloudws-$TAG/disk.raw.tar.gz \
  --family=cloudws-bootc \
  --guest-os-features=UEFI_COMPATIBLE,GVNIC,VIRTIO_SCSI_MULTIQUEUE
```

**UEFI / Shielded VM.** `UEFI_COMPATIBLE` is the image-level flag;
`--shielded-secure-boot`, `--shielded-vtpm`, and
`--shielded-integrity-monitoring` are per-instance. Fedora bootc's signed
shim chain is trusted by Shielded VM's default Microsoft UEFI CA DB out of
the box — no custom MOK enrolment needed unless you layer third-party
kernel modules.

## 3. Google Guest Environment

Fedora 41/42 ships `google-guest-agent`,
`google-compute-engine-guest-configs`, and `google-compute-engine-oslogin`
in the main repos. `14-gcp-guest-environment.sh` layers them and enables:

- `google-guest-agent-manager.service` (the plugin manager; the legacy
  `google-guest-agent.service` ships disabled since 2025-09).
- `google-startup-scripts.service` / `google-shutdown-scripts.service`.
- `google-oslogin-cache.timer`, `google-disk-expand.service`.

**OS Login** is wired in automatically: the agent rewrites
`/etc/nsswitch.conf` (`passwd: cache_oslogin oslogin files systemd`),
installs the PAM modules, and configures sshd's `AuthorizedKeysCommand
/usr/bin/google_authorized_keys`. This means both SSH **and Cockpit** get
Google SSO via IAM roles `roles/compute.osLogin` and
`roles/compute.osAdminLogin` for free.

**Disk resize**: `google-disk-expand.service` is the canonical path on
RHEL-family images; cloud-init's `growpart` is enabled as a belt-and-braces
fallback.

## 4. cloud-init + GCE datasource

`15-cloud-init.sh` installs cloud-init and `99-cloudws-gcp.cfg` pins
`datasource_list: [GCE, None]`, disables package install modules (bootc's
`/usr` is immutable), and delegates SSH-key management to google-guest-agent
via `AuthorizedKeysCommand`. `runcmd` and user-data still work for one-shot
provisioning from the Terraform `metadata.user-data` field.

Validate with `cloud-init status --wait` and
`cloud-init schema --system`.

## 5. GAR authentication

`/etc/ostree/auth.json` is the pull secret for `bootc upgrade`. The
`gar-auth-refresh.timer` runs every 30 min and rewrites that file with a
fresh `oauth2accesstoken:…` base64 blob from the instance's service-account
token (via `169.254.169.254`). No gcloud dependency. Same token source
works for runtime `podman pull` of VDI containers hosted in GAR.

For cosign-signed images, `/etc/containers/registries.d/*.yaml` sets
`use-sigstore-attachments: true` so the signatures pushed alongside the
image in GAR are visible to the containers/image policy engine. Note:
`bootc upgrade` as of early 2026 still only best-effort enforces
`/etc/containers/policy.json` sigstore verification
(bootc-dev/bootc#528/#218). `bootc install`/`switch` do enforce it.
Treat keyless signing as defense in depth, not as a gate.

## 6. Workload Identity Federation (CI/CD)

The `iam.tf` module creates a pool `github` with a provider bound to
`token.actions.githubusercontent.com` and the mandatory
`attribute_condition = "assertion.repository == 'Kabuki94/CloudWS-bootc'"`.
(Providers without an attribute condition are rejected by GCP since 2024.)
The `gha-cloudws-push` service account gets `artifactregistry.writer` on
the repo and `storage.objectAdmin` on the staging bucket; GitHub's OIDC
token is exchanged for a short-lived GCP access token with no JSON keys.

## 7. Cloud Workstations

Cloud Workstations runs the supplied image as a *container* inside a
GKE-managed sandbox VM. It never calls `bootc install`. Because a bootc
image is also a valid OCI image, the same `ghcr.io/kabuki94/cloudws-bootc`
tag can be consumed as the workstation container — you just need a blocking
ENTRYPOINT (systemd-as-PID1 needs `--privileged`, which Cloud Workstations
does not grant; prefer `/usr/local/bin/start-vdi.sh` that launches
sshd + KasmVNC + guacd and `exec sleep infinity`). The Terraform module
exposes this via `container { image = "…cloudws-bootc:${var.image_tag}" }`.

Persistence: `/home` is a managed PD that survives stop/start. Everything
outside `/home` is ephemeral — cache git/`.m2`/`.gradle` in `/home`.

Access: IAP-fronted URL (`*.cloudworkstations.dev`). JetBrains Gateway has
a native Cloud Workstations provider; VS Code Remote SSH uses
`gcloud workstations start-tcp-tunnel ws 22 --local-host-port=localhost:2222`.

## 8. GKE patterns

Three patterns, in increasing order of "correctness":

1. **Privileged Pod with systemd-as-PID1** — works but requires
   `privileged: true`, a writable cgroup mount, and emptyDir tmpfs for
   `/run`, `/tmp`. Fragile and not the upstream design.
2. **Lightweight Pod with a non-systemd entrypoint** (Kasm pattern) —
   ships a `start-vdi.sh` that launches sshd + the VDI stack, no systemd.
   Good for disposable sessions.
3. **KubeVirt VM via containerDisk** — the canonical pattern. Wrap a
   qcow2 (produced by `bootc-image-builder --type qcow2`) in a
   `FROM scratch; ADD cloudws.qcow2 /disk/` image, push to GAR, reference
   from a `VirtualMachine` CR. Requires nested virtualization on the node
   pool: `UBUNTU_CONTAINERD`, or `COS_CONTAINERD` on >= 1.28.4-gke.1083000
   (GKE node-pool create flag `--enable-nested-virtualization`).

CloudWS-bootc as a GKE **node** OS is not supported on managed GKE; the
node image menu is COS / Ubuntu only. Future work = GKE-on-bare-metal.

## 9. Browser-native VDI stack

The VDI Quadlets live under `/etc/containers/systemd/` and compose into
`cloudws-vdi.target`:

- `cloudws-vdi.network` — isolated bridge
- `cloudws-guacamole-db.{volume,container}` — PostgreSQL 16
- `cloudws-guacd.container` — `guacamole/guacd:1.6.0` on :4822
- `cloudws-guacamole.container` — `guacamole/guacamole:1.6.0` on :8080
  with `HTTP_AUTH_ENABLED=true` and `HTTP_AUTH_HEADER=X-Goog-Authenticated-User-Email`
  so IAP's signed header becomes the logged-in user.
- `cloudws-kasmvnc.container` — `kasmweb/core-ubuntu-noble:1.18.0`
  (requires `--shm-size=512m`, honors NVIDIA CDI via `PodmanArgs=`)
- `cloudws-vdi-nginx.container` — nginx 1.27-alpine with the
  `/usr/share/cloudws/vdi/nginx-vdi.conf` reverse proxy config

The nginx config proxies `/guacamole/`, `/kasmvnc/`, and `/cockpit/`
(loopback to 9090), all with WebSocket upgrade and
`proxy_buffering off` (mandatory for Guacamole). The host-level :443
publish port is fronted by a Google HTTPS LB with IAP enabled — that LB
injects the `X-Goog-Authenticated-User-Email` and
`X-Goog-IAP-JWT-Assertion` headers consumed by Guacamole's header-auth
extension. No pixels ever leave the VPC; only the HTML5 WebSocket stream
reaches the browser.

**GNOME 50 caveat.** GNOME 50 (March 2026) is Wayland-only; KasmVNC is
X11-only. Inside a VDI container, run XFCE, MATE, or Plasma-X11. On
bare-metal GNOME (a Compute Engine VM with a physical-ish compositor),
stay on Wayland. `/usr/libexec/cloudws/vdi-session-prepare` detects
context and emits `XDG_SESSION_TYPE` + toolkit-backend env vars.

## 10. Cockpit on loopback

Cockpit is installed directly into `/usr` by `17-cockpit-sysext.sh`. The
`cockpit.socket` listens on 9090/TCP; PAM uses `pam_oslogin_login.so` by
transitive include of the system auth stack, so IAM-granted OS Login
users get Cockpit access automatically.

Cockpit's self-signed cert is fine — IAP terminates TLS at the LB, or
the operator tunnels `9090` via `gcloud compute start-iap-tunnel`.

Upstream `tools/make-sysext` is a developer workflow and is **not**
SELinux-enforcing-policy-complete. For production on bootc we bake
Cockpit in; `cloudws-cockpit-sysext.service` is kept only for optional
runtime extension drops into `/var/lib/extensions/`.

## 11. DNS / Private Google Access

`metadata.google.internal` resolves through the DHCP-provided nameserver
`169.254.169.254` which also acts as the DNS authority for
`*.c.PROJECT.internal`. For private-only deployments, add a Cloud DNS
private zone for `googleapis.com` mapping `*` to
`private.googleapis.com` (199.36.153.8-11) plus zones for `pkg.dev`,
`gcr.io`, `gke.goog`, `pki.goog`. Cloud NAT is required for egress to
`ghcr.io` / `quay.io` since those are outside Private Google Access.

`/usr/libexec/cloudws/gcp-firstboot` polls the MDS for 60 s before
proceeding; this is the "DNS guard" used across the provisioning chain.

## 12. IAM reference

| Principal | Role | Scope |
|---|---|---|
| `cloudws-vm@…` (VM runtime) | `roles/artifactregistry.reader` | GAR repo |
| `cloudws-ws@…` (workstation) | `roles/artifactregistry.reader` | GAR repo |
| `cloudws-gke-node@…` | `roles/artifactregistry.reader` | GAR repo |
| `gha-cloudws-push@…` | `roles/artifactregistry.writer` | GAR repo |
| `gha-cloudws-push@…` | `roles/storage.objectAdmin` | staging bucket |
| human admins | `roles/iap.tunnelResourceAccessor` | instance/tunnel |
| human users | `roles/iap.httpsResourceAccessor` | LB backend service |
| human users | `roles/compute.osLogin` + `workstations.user` | project |

## 13. Troubleshooting

- **`google_compute_image` fails "UEFI feature not available"** — check
  the org policy `compute.trustedImageProjects`/`compute.disableUEFI`;
  some old projects inherit a block.
- **`raw_disk.source` rejected as `gs://…`** — the Compute API requires
  `https://storage.googleapis.com/BUCKET/OBJECT`, not the `gs://` form.
  Terraform passes the value through unchanged.
- **`bootc upgrade` 403 on GAR** — token expired; check
  `systemctl status gar-auth-refresh.timer` and `journalctl -u
  gar-auth-refresh`.
- **eth0 vs ens4 split after `bootc install to-existing-root`** — add
  `net.ifnames=0 biosdevname=0` to `kargs.d/03-cloudws-gcp.toml` (we do).
- **Cockpit `203/EXEC`** — SELinux mislabel on `cockpit-tls` /
  `cockpit-session`; fixed in cockpit >= 330. CloudWS ships recent.
- **Guacamole WebSocket fails** — check `proxy_buffering off` and the
  `Connection $connection_upgrade` map in nginx; both are mandatory.

## 14. Production checklist

- [ ] WIF provider has `attribute_condition` pinned to the repo
- [ ] `use-sigstore-attachments: true` under `/etc/containers/registries.d/`
- [ ] `cloudws-gcp-firstboot.done` present after first boot
- [ ] `gar-auth-refresh.timer` active and recent
- [ ] `systemctl --failed` empty
- [ ] `podman-auto-update.timer` enabled
- [ ] IAP firewall rule limits source to `35.235.240.0/20`
- [ ] Shielded-VM integrity monitoring reports green
- [ ] cosign verify passes with the pinned certificate-identity regex
