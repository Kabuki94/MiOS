# Universal AI Memory (Level 1)
## Repository: CloudWS-bootc
## Basis: Claude OS | Shadow: Google Gemini

### Synchronized Project State
- **Shared Memories**: `.claude/memories/` (Journal, Vaults)
- **Shared Scratchpad**: `.claude/shared-tmp/` (Universal TMPDIR)
- **Baseline**: v1.3.0
- **Mandate**: Shadow Copy Architecture (Twin agents, one brain)

### Active Protocols
- **Journaling**: Both agents write to [`.claude/memories/journal.md`](../memories/journal.md).
- **Communication**: Inter-agent data exchange via `.claude/shared-tmp/`.
- **Implementation**: Gemini executes; Claude remembers; both synchronize.

### Architecture Update Complete (2026-04-25)
- Shared scratchpad provisioned.
- `AI.md` and `.ai-rules` updated to formalize the **Shadow Copy** relationship.
- All AI metadata consolidated into the shared Claude OS basis.
