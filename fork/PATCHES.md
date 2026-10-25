# Fork patches

Each patch is one commit on `main` (subject starting `fork:`). Newest last.

## 1. OpenCode may reach a model server on the local network over plain HTTP

- **Why:** Genex runs OpenCode in its sandbox and opens the network only to the hosts a provider
  answers on. It took a provider's host only from an `https://` address, so a self-hosted
  OpenAI-compatible server (`http://192.168.0.224:8888/v1`) got no host, every request was refused by
  the sandbox's proxy, and the build stopped with "Genex doesn't know where tensorfold answers".
- **Change:** `apiHost` (`src/substrate/engines/opencode-cli.ts`) also accepts an `http://` address
  whose host is on this computer or the local network — the same rule Genex's own Local server
  provider uses (`isLocalIp`, `src/substrate/local-server/address.ts`: loopback, RFC 1918, link-local,
  the tailnet range). Plain HTTP to anywhere else is still refused; HTTPS is unchanged.
- **Tests:** `tests/conformance/engine-opencode.test.ts` (44 pass).
- **Upstream:** a good candidate for a PR.

## 2. Assume a large context window for local servers Genex can't probe

- **Why:** For an OpenAI-compatible server of no known kind (not TabbyAPI, llama.cpp, LM Studio, vLLM,
  KoboldCpp or Ollama), Genex can't read the model's context window and records the 32,768 default.
  The Contractor's fixed instructions and tools alone are ~33K tokens, so every build stopped after 0
  turns with `context_overflow`, though the model (Qwen3.8-Flash-Next) has 262,144.
- **Change:** `resolveContextWindow` (`src/harness-seed/loop/tool-loop.ts`) returns 262,144 — or
  `HARNESS_LOCAL_CONTEXT` — for a local-server model recorded at 32,768 or less.
- **Note:** this is harness seed code. The same edit is in the live copy
  `~/.config/Genex/workspaces/harness/loop/tool-loop.ts`, which Genex keeps as yours from now on.
- **Tests:** `tests/conformance/engine-delegated.test.ts` (71 pass); typecheck.
- **Upstream:** better fixed there by letting the user set a local server's context window.
