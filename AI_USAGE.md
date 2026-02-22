# 🤖 Local AI Usage Guide

Practical guide for running local LLMs with **Ollama** and **llama.cpp** on the Asus ExpertBook setup.

> Both tools run inside the `dev-ai` Distrobox container and are exported to the host. See the main README for setup instructions.

---

## 📑 Table of Contents
1. [Finding Models](#-1-finding-models)
2. [Ollama](#-2-ollama)
3. [llama.cpp](#-3-llamacpp)
4. [Recommended Models by Use Case](#-4-recommended-models-by-use-case)

---

## 🔍 1. Finding Models

### Ollama Library

The easiest way to browse models is the official Ollama library:

```
https://ollama.com/library
```

Search by name, filter by size, and check the available quantizations (e.g. `q4_K_M`, `q8_0`). Each model page shows the pull command directly.

```bash
# Search from the CLI
ollama search qwen
ollama search llama
ollama search codellama
```

### Hugging Face (for llama.cpp / GGUF)

For llama.cpp you need models in **GGUF format**. The best source is Hugging Face:

```
https://huggingface.co/models?library=gguf
```

Well-known providers of pre-quantized GGUF models:
- **bartowski** — wide selection, well quantized
- **unsloth** — optimized quants
- **lmstudio-community** — curated, tested models

Search tip: add `GGUF` to any model name on HuggingFace, e.g. `Qwen2.5-7B-Instruct GGUF`.

### Quantization Guide

Lower quantization = smaller file, lower quality. Higher = better quality, more RAM.

| Format | Size | Quality | RAM (7B model) |
|--------|------|---------|----------------|
| Q2_K | Tiny | Poor | ~3 GB |
| Q4_K_M | Small | Good | ~5 GB |
| Q5_K_M | Medium | Very good | ~6 GB |
| Q8_0 | Large | Excellent | ~8 GB |
| F16 | Full | Best | ~14 GB |

**Recommended for this hardware (32GB RAM): Q4_K_M or Q5_K_M**

---

## 🦙 2. Ollama

### Starting the Server

Ollama runs as a background server. Start it from the host:

```bash
ollama-serve   # alias defined in ~/.bashrc
```

Verify it's running:

```bash
ollama ps      # shows loaded models
curl http://localhost:11434   # should return "Ollama is running"
```

### Managing Models

```bash
# Download a model
ollama pull qwen2.5:0.5b
ollama pull llama3.2
ollama pull llama3.2:1b
ollama pull codellama:7b

# List downloaded models
ollama list

# Remove a model
ollama rm llama3.2

# Show model info
ollama show llama3.2
```

### Running Models

```bash
# Interactive chat
ollama run qwen2.5:0.5b

# Single prompt (non-interactive)
ollama run qwen2.5:0.5b "explain what a neural network is in 3 sentences"

# With performance stats
ollama run qwen2.5:0.5b "hola" --verbose

# Pass a file as context
ollama run llama3.2 "summarize this code:" < myfile.py
```

### Useful Parameters

```bash
# Set context window size
ollama run llama3.2 --ctx-size 8192

# Keep model loaded in memory (avoids reload delay)
ollama run llama3.2 --keep-alive 30m

# Change system prompt
ollama run llama3.2 --system "You are a senior Python developer. Be concise."
```

### REST API

Ollama exposes an OpenAI-compatible API at `http://localhost:11434`. Use it to integrate with editors, scripts, or apps:

```bash
# Simple generation
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5:0.5b",
  "prompt": "What is the capital of France?",
  "stream": false
}'

# Chat format (OpenAI-compatible)
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:0.5b",
    "messages": [{"role": "user", "content": "hola"}]
  }'
```

```python
# Python — using openai SDK pointed at local Ollama
from openai import OpenAI

client = OpenAI(base_url="http://localhost:11434/v1", api_key="ollama")
response = client.chat.completions.create(
    model="qwen2.5:0.5b",
    messages=[{"role": "user", "content": "explain recursion briefly"}]
)
print(response.choices[0].message.content)
```

### Modelfile — Custom Models

You can customize any model with a `Modelfile`:

```dockerfile
FROM llama3.2

SYSTEM """
You are a senior software engineer. 
Answer questions concisely and always show code examples.
"""

PARAMETER temperature 0.3
PARAMETER num_ctx 8192
```

```bash
ollama create my-dev-assistant -f Modelfile
ollama run my-dev-assistant
```

---

## ⚡ 3. llama.cpp

llama.cpp is significantly faster than Ollama on CPU (~64 tok/s vs ~3-5 tok/s) and gives more control over inference parameters.

### Downloading GGUF Models

```bash
# From Hugging Face — always check the model page for the exact filename
wget https://huggingface.co/<author>/<repo>/resolve/main/<filename>.gguf -P ~/Models/

# Example: Qwen2.5 0.5B
wget https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf -P ~/Models/

# Example: Qwen2.5 7B (larger, better quality)
wget https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf -P ~/Models/
```

Tip: use `huggingface-cli` inside the container for easier browsing and downloading:

```bash
pip install huggingface_hub --break-system-packages
huggingface-cli download bartowski/Qwen2.5-7B-Instruct-GGUF \
  Qwen2.5-7B-Instruct-Q4_K_M.gguf \
  --local-dir ~/Models/
```

### Basic Usage

```bash
# Interactive chat (default mode)
llama-cli -m ~/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf

# Single prompt, no interactive mode
llama-cli -m ~/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf \
  -p "explain what an API is" \
  -n 200 \
  --no-display-prompt

# Pipe input
echo "what is Docker?" | llama-cli -m ~/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf -n 200
```

### Useful Parameters

```bash
-n 200          # max tokens to generate
-c 4096         # context window size
--temp 0.7      # temperature (0 = deterministic, 1 = creative)
--top-p 0.9     # nucleus sampling
-t 8            # number of CPU threads (default: all)
--repeat-penalty 1.1  # reduce repetition
```

### llama-server — OpenAI-Compatible API

Run llama.cpp as a server compatible with the OpenAI API:

```bash
# Inside the container or via distrobox
llama-server \
  -m ~/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf \
  --port 8080 \
  --ctx-size 4096 \
  -t 8
```

Test it:

```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5",
    "messages": [{"role": "user", "content": "hola"}]
  }'
```

Export the server binary to the host as well:

```bash
# Inside the container
distrobox-export --bin /home/$USER/Projects/llama.cpp/build/bin/llama-server
```

---

## 🎯 4. Recommended Models by Use Case

### General Chat

| Model | Size | Tool | Notes |
|-------|------|------|-------|
| `qwen2.5:0.5b` | 0.5B | Ollama / llama.cpp | Fast, good for quick tasks |
| `qwen2.5:7b` | 7B | Ollama / llama.cpp | Best quality/speed balance |
| `llama3.2:3b` | 3B | Ollama | Good multilingual support |

### Coding Assistant

| Model | Size | Tool | Notes |
|-------|------|------|-------|
| `codellama:7b` | 7B | Ollama | Solid code completion |
| `qwen2.5-coder:7b` | 7B | Ollama | Excellent for code, multilingual |
| `deepseek-coder-v2:16b` | 16B | Ollama | Best quality, needs more RAM |

### Small / Fast (NPU-friendly)

| Model | Size | Tool | Notes |
|-------|------|------|-------|
| `qwen2.5:0.5b` | 0.5B | OpenVINO GenAI | Works on NPU |
| `smollm2:135m` | 135M | Ollama | Tiny, extremely fast |

### Finding the Right Size for Your RAM

With 32GB RAM on this machine:

- **0.5B–3B** — runs comfortably, leaves plenty of RAM free
- **7B Q4_K_M** — ideal balance, ~5GB VRAM/RAM
- **13B Q4_K_M** — feasible, ~9GB RAM
- **32B Q4_K_M** — possible but slow on CPU (~18GB RAM)
- **70B+** — not practical without discrete GPU

---

## 💡 Tips

**Check model performance before committing to a large download:**
```bash
ollama run qwen2.5:0.5b "write a Python function that reverses a string" --verbose
```

**Use llama.cpp for speed, Ollama for convenience:**
- llama.cpp: scripting, pipelines, maximum speed
- Ollama: interactive chat, API integrations, model management

**Keep models organized:**
```bash
ls -lh ~/Models/   # check disk usage
du -sh ~/Models/*  # size per model
```
