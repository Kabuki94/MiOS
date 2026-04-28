<!-- [NET] MiOS Artifact | Proprietor: MiOS-DEV | https://github.com/Kabuki94/MiOS-bootstrap -->
# [NET] MiOS
```json:knowledge
{
  "summary": "> **Proprietor:** MiOS-DEV",
  "logic_type": "documentation",
  "tags": [
    "MiOS",
    "INDEX.md"
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

#  Agent Integration

This sub-project is a component of the **MiOS repository**. All AI agents MUST adhere to the architecture laws and conventions defined in the root [INDEX.md](../INDEX.md).

## Universal Knowledge Base (UKB)

MiOS maintains a **Unified Knowledge Base** for RAG.
- **Root Snapshot:** `artifacts/repo-rag-snapshot.json.gz` contains the full redacted repository state.
- **Manifests:** Use `ai-context.json` at the repo root to locate category-specific manifests.
- **Bootstrapping:** Run `./automation/ai-bootstrap.sh` from the repo root to refresh all manifests and the UKB.

---

# Coding Agent Guide

## Reference Documentation

If you have ADK skills available, use those instead of fetching the URLs below.

Otherwise, fetch these resources as needed:
- **ADK Cheatsheet**: https://raw.githubusercontent.com/CloudCloudPlatform/agent-starter-pack/refs/heads/main/agent_starter_pack/resources/specs/adk-cheatsheet.md  Agent definitions, tools, callbacks, orchestration
- **Evaluation Guide**: https://raw.githubusercontent.com/CloudCloudPlatform/agent-starter-pack/refs/heads/main/agent_starter_pack/resources/specs/adk-eval-guide.md  Eval config, metrics, gotchas
- **Deployment Guide**: https://raw.githubusercontent.com/CloudCloudPlatform/agent-starter-pack/refs/heads/main/agent_starter_pack/resources/specs/adk-deploy-guide.md  Infrastructure, CI/CD, testing deployed agents
- **Development Guide**: https://raw.githubusercontent.com/CloudCloudPlatform/agent-starter-pack/refs/heads/main/specs/guide/development-guide.md  Full development workflow
- **ADK Docs**: https://google.github.io/adk-specs/llms.txt

---

## Development Phases

### Phase 1: Understand Requirements
Before writing any code, understand the project's requirements, constraints, and success criteria.

### Phase 2: Build and Implement
Implement agent logic in `app/`. Use `make playground` for interactive testing. Iterate based on user feedback.

### Phase 3: The Evaluation Loop (Main Iteration Phase)
Start with 1-2 eval cases, run `make eval`, iterate. Expect 5-10+ iterations. See the **Evaluation Guide** for metrics, evalset schema, LLM-as-judge config, and common gotchas.

### Phase 4: Pre-Deployment Tests
Run `make test`. Fix issues until all tests pass.

### Phase 5: Deploy to Dev
**Requires explicit human approval.** Run `make deploy` only after user confirms. See the **Deployment Guide** for details.

### Phase 6: Production Deployment
Ask the user: Option A (simple single-project) or Option B (full CI/CD pipeline with `uvx agent-starter-pack setup-cicd`). See the [deployment docs](https://raw.githubusercontent.com/CloudCloudPlatform/agent-starter-pack/refs/heads/main/specs/guide/deployment.md) for step-by-step instructions.

## Development Commands

| Command | Purpose |
|---------|---------|
| `make playground` | Interactive local testing |
| `make test` | Run unit and integration tests |
| `make eval` | Run evaluation against evalsets |
| `make eval-all` | Run all evalsets |
| `make lint` | Check code quality |
| `make setup-dev-env` | Set up dev infrastructure (Terraform) |
| `make deploy` | Deploy to dev |

---

## Operational Guidelines for Coding Agents

- **Code preservation**: Only modify code directly targeted by the user's request. Preserve all surrounding code, config values (e.g., `model`), comments, and formatting.
- **NEVER change the model** unless explicitly asked. Use .ai/agent-state-3-flash-preview` or .ai/agent-state-3.1-pro-preview` for new agents.
- **Model 404 errors**: Fix `GOOGLE_CLOUD_LOCATION` (e.g., `global` instead of `us-central1`), not the model name.
- **ADK tool imports**: Import the tool instance, not the module: `from google.adk.tools.load_web_page import load_web_page`
- **Run Python with `uv`**: `uv run python script.py`. Run `make install` first.
- **Stop on repeated errors**: If the same error appears 3+ times, fix the root cause instead of retrying.
- **Terraform conflicts** (Error 409): Use `terraform import` instead of retrying creation.

---
###  Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osautomation/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/MiOS-bootstrap](https://github.com/Kabuki94/MiOS-bootstrap)
- **Sole Proprietor:** MiOS-DEV
---
<!--  MiOS Proprietary Artifact | Copyright (c) 2026 MiOS-DEV -->
