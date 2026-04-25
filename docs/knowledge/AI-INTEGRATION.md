# 🤖 CloudWS AI Integration

# 🌐 CloudWS-bootc — Universal AI Integration
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---

This document outlines the AI shell assistant and local LLM integration within CloudWS-bootc.

## 🚀 Overview
CloudWS-bootc features a modern, local-first AI stack designed for high-performance coding, system automation, and mathematical reasoning. The stack is fully containerized and integrated directly into the system shell.

## 🛠️ Core Components

### 1. Ollama (Local LLM Backend)
**Ollama** runs as a containerized service managed by systemd Quadlets.
- **Service Name:** `ollama.service`
- **Model Path:** `/var/lib/ollama` (Persistent)
- **API Endpoint:** `http://localhost:11434`
- **Acceleration:** Automatic NVIDIA GPU passthrough (via `nvidia-container-toolkit`).

### 2. AIChat & AIChat-NG (Shell Assistants)
Two powerful Rust-based CLI tools function as the primary interfaces for the LLM stack.
- **`aichat`**: The standard all-in-one LLM CLI.
- **`aichat-ng`**: An enhanced fork featuring response editing and optimized Ollama support.

## 🧠 Model Standards
The system defaults to high-performance, open-license models:
- **Default Coding Model:** `deepseek-coder-v2:lite` (Apache 2.0)
  - *Optimized for:* Windows PowerShell, Linux Bash, Python, and C++.
  - *Configuration:* Pre-pulled and embedded during local builds.
- **Recommended Math Model:** `qwen2.5` (Apache 2.0)
  - *Optimized for:* Algorithmic reasoning and logic.

## ⌨️ Usage & Management

### CloudWS CLI Commands
The `cloudws` tool provides simplified management for the AI stack:
- `cloudws ai`: Display status and version information.
- `cloudws ai-logs`: View real-time logs from the Ollama backend.
- `cloudws ai-pull <model>`: Download new models (defaults to `deepseek-coder-v2:lite`).

### Shell Integration
Both `aichat` and `aichat-ng` are pre-configured to use the local Ollama instance.
- Run `aichat "How do I list listening ports in PowerShell?"` for instant command generation.
- Run `aichat-ng` to enter an interactive REPL session with persistent history.

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/CloudWS-bootc](https://github.com/Kabuki94/CloudWS-bootc)
- **Sole Proprietor:** Kabu.ki
---
