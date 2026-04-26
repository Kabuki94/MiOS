<!-- 🌐 MiOS Artifact | Proprietor: Kabu.ki | https://github.com/kabuki94/mios -->
```json:knowledge
{
  "summary": "This devcontainer provides a development environment for the MiOS repository.\\n\\nWhat it includes\\n-...",
  "logic_type": "documentation",
  "tags": [
    "MiOS",
    "README.md"
  ],
  "relations": {
    "depends_on": [
      ".env.mios"
    ],
    "impacts": []
  }
}
```
This devcontainer provides a development environment for the MiOS repository.\n\nWhat it includes\n- Podman, Buildah, Skopeo, Docker CLI + Docker-in-Docker feature\n- QEMU user tools for cross-building images\n- Scripts to install kubectl and Helm in container\n- Recommended VS Code extensions for Docker/Kubernetes/C/C++/Makefile\n\nNotes\n- The container requests --privileged and mounts /dev/kvm so that QEMU/KVM can be used. On some hosts (Codespaces, some constrained environments) privileged mode or /dev/kvm may be unavailable. If you cannot run privileged containers, remove "runArgs" and the /dev/kvm mount in devcontainer.json and use host tools for VM access.\n- After I push these files I recommend testing by opening the repo in VS Code Remote - Containers or Codespaces and letting the postCreateCommand run.\n\nTesting checklist\n- Open the repository in VS Code and choose "Reopen in Container".\n- Verify kubectl and helm exist (or run .devcontainer/scripts/setup.sh manually).\n- Try podman --version and buildah --version.\n- If you need to use KVM inside the container, ensure the host allows /dev/kvm and run with privileged.\n\nSecurity / environment notes\n- The devcontainer requests privileged mode and mounts /dev/kvm to enable image and VM tooling. If you prefer a less privileged container, I can remove those and document required host steps instead.\n- Some tooling (libvirt/kvm) is not fully reliable in containerized environments. For heavy VM workflows consider using host tooling or a VM-based dev environment.
<!-- ⚖️ MiOS Proprietary Artifact | Copyright (c) 2026 Kabu.ki -->
