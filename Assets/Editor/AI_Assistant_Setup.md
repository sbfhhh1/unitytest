# Unity AI Assistant setup

## Official Unity AI Assistant

This project uses Unity `6000.3.2f1`, which matches the Unity 6.3+ requirement for the official Unity AI Assistant package.

Package to install:

```text
com.unity.ai.assistant
```

Open it in Unity with:

```text
AI > Assistant
```

Required Unity-side setup:

1. Sign in to Unity Hub and Unity Editor with the same Unity account.
2. Link the project to a Unity Cloud project from `Edit > Project Settings > Services`.
3. Accept Unity AI terms and make sure the account has Unity AI points or an eligible plan.
4. Use `Window > Package Manager > Add package by name...` and enter `com.unity.ai.assistant` if the package did not resolve automatically.

Current local status:

```text
Unity Package Manager reached the install request, but DNS lookup for cdn.packages.unity.com failed on this machine.
```

Retry installation after the machine can resolve Unity package servers.

## Custom mainstream model configuration

The official Unity AI Assistant does not currently expose a general provider switch for OpenAI, Anthropic Claude, Google Gemini, DeepSeek, or local Ollama models. This project therefore includes a separate Editor tool:

```text
AI > Custom Model Assistant
```

Supported presets:

- OpenAI-compatible APIs, including OpenAI-compatible third-party gateways
- DeepSeek
- Anthropic Claude
- Google Gemini
- Local Ollama

The API key is stored in Unity `EditorPrefs` on this machine, not as a project asset.

Typical model settings:

```text
OpenAI
Endpoint: https://api.openai.com/v1/chat/completions
Model: gpt-4.1

DeepSeek
Endpoint: https://api.deepseek.com/chat/completions
Model: deepseek-chat

Claude
Endpoint: https://api.anthropic.com/v1/messages
Model: claude-sonnet-4-5

Gemini
Endpoint: https://generativelanguage.googleapis.com/v1beta
Model: gemini-2.5-pro

Ollama
Endpoint: http://localhost:11434/api/chat
Model: qwen2.5-coder
```

For Ollama, start the local service first and pull a model, for example:

```powershell
ollama pull qwen2.5-coder
```

Then open `AI > Custom Model Assistant`, choose `Ollama`, and press `Send Test Prompt`.
