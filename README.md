# rangallama

A dumb simple ollama alternative. One bash script, Ubuntu only, Vulkan only, a handful of [unsloth](https://unsloth.ai/) models.

Builds llama.cpp from source with Vulkan support and downloads quantized GGUFs from unsloth on HuggingFace.

## Requirements

- Ubuntu (or derivative)
- Vulkan-capable GPU

## Usage

```bash
# Interactive chat
./rangallama.sh run gemma-4-e2b

# OpenAI-compatible server
./rangallama.sh serve gemma-4-26b-a4b

# Point Claude Code at it
ANTHROPIC_BASE_URL=http://127.0.0.1:6969 claude
```

## Available models

| Name | Run | Serve |
|------|-----|-------|
| gemma-4-e2b | yes | no |
| gemma-4-e4b | yes | no |
| gemma-4-26b-a4b | yes | yes |
| qwen3.5-35b-a3b | yes | yes |

First run will install build dependencies, clone and compile llama.cpp, and download the model weights. Subsequent runs skip all that.
