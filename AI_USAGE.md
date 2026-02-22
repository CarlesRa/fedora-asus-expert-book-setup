# 🤖 Local AI Usage Guide

Practical guide for running local LLMs with **Ollama**, **llama.cpp**, and **Open WebUI** on the Asus ExpertBook setup.

> All tools run inside the `dev-ai` Distrobox container and are exported to the host. See the main README for setup instructions.

---

## 📑 Table of Contents
1. [Finding Models](#-1-finding-models)
2. [Daily Workflow](#-2-daily-workflow)
3. [Ollama](#-3-ollama)
4. [llama.cpp](#-4-llamacpp)
5. [Open WebUI](#-5-open-webui)
6. [Recommended Models by Use Case](#-6-recommended-models-by-use-case)

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

## ⚡ 2. Daily Workflow

Start everything from the host with aliases:

```bash
llama-serve    # Start llama-server (~64 tok/s) on port 8081
webui          # Start Open WebUI at http://localhost:8080
```

Or if you prefer Ollama over llama-server:

```bash
ollama-serve   # Start Ollama on port 11434
webui          # Start Open WebUI at http://localhost:8080
```

Open WebUI is available at `http://localhost:8080`. Select the model in the top dropdown:
- **GGUF model** (e.g. `qwen2.5-0.5b-instruct-q4_k_m.gguf`) → uses llama-server, ~64 tok/s
- **Ollama model** (e.g. `qwen2.5:0.5b`) → uses Ollama, ~3-5 tok/s

---

## 🦙 3. Ollama

### Managing Models

```bash
# Download a model
ollama pull qwen2.5:0.5b
ollama pull llama3.2
ollama pull codellama:7b

# List downloaded models
ollama list

# Remove a model
ollama rm llama3.2

# Show model info
ollama show llama3.2
```

### Running Models from CLI

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
ollama run llama3.2 --ctx-size 8192                              # Set context window
ollama run llama3.2 --keep-alive 30m                             # Keep model in memory
ollama run llama3.2 --system "You are a senior Python developer" # Custom system prompt
```

### REST API

Ollama exposes an OpenAI-compatible API at `http://localhost:11434`:

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5:0.5b",
  "prompt": "What is the capital of France?",
  "stream": false
}'
```

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:11434/v1", api_key="ollama")
response = client.chat.completions.create(
    model="qwen2.5:0.5b",
    messages=[{"role": "user", "content": "explain recursion briefly"}]
)
print(response.choices[0].message.content)
```

### Modelfile — Custom Models

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

## ⚡ 4. llama.cpp

llama.cpp is significantly faster than Ollama on CPU (~64 tok/s vs ~3-5 tok/s).

### Downloading GGUF Models

```bash
# From Hugging Face
wget https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf -P ~/Models/

# Larger model (better quality)
wget https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf -P ~/Models/
```

Using `huggingface-cli` (inside the container):

```bash
pip install huggingface_hub --break-system-packages
huggingface-cli download bartowski/Qwen2.5-7B-Instruct-GGUF \
  Qwen2.5-7B-Instruct-Q4_K_M.gguf \
  --local-dir ~/Models/
```

### CLI Usage

```bash
# Interactive chat
llama-cli -m ~/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf

# Single prompt
llama-cli -m ~/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf \
  -p "explain what an API is" -n 200 --no-display-prompt

# Useful parameters
-n 200          # max tokens to generate
-c 4096         # context window size
--temp 0.7      # temperature
-t 8            # CPU threads
```

### llama-server — OpenAI-Compatible API

Run as a server for use with Open WebUI or any OpenAI-compatible client:

```bash
# Already configured via alias:
llama-serve    # starts on port 8081

# Or manually with custom options:
llama-server -m ~/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf --port 8081 --ctx-size 4096
```

Test the API:

```bash
curl http://localhost:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen2.5", "messages": [{"role": "user", "content": "hola"}]}'
```

---

## 🖥️ 5. Open WebUI

A full-featured ChatGPT-like interface with RAG support — upload PDFs, documents, and web pages as context for your conversations.

### Starting

```bash
webui    # starts at http://localhost:8080
```

### Connecting to llama-server (Recommended — ~64 tok/s)

1. Go to **Admin Panel → Settings → Connections**
2. Under **API OpenAI**, click **+** and add:
   - **URL:** `http://localhost:8081/v1`
   - **API Key:** `llama` (any text)
3. Save and select the GGUF model in the chat dropdown

### Using RAG

1. Click the **+** icon in the chat input
2. Upload a PDF, text file, or paste a URL
3. The document is indexed and used as context for your conversation

You can also create persistent **Knowledge Bases** via **Workspace → Knowledge** — useful for ongoing projects or documentation.

### Tips

- Use **llama-server** as backend for speed, **Ollama** for model variety
- The **Arena Model** option lets you compare two models side by side
- **Notes** feature works as a local scratchpad integrated with the AI

---

## 🎯 6. Recommended Models by Use Case

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
| `qwen2.5-coder:7b` | 7B | Ollama | Excellent for code |
| `deepseek-coder-v2:16b` | 16B | Ollama | Best quality, needs more RAM |

### Small / Fast (NPU-friendly)

| Model | Size | Tool | Notes |
|-------|------|------|-------|
| `qwen2.5:0.5b` | 0.5B | OpenVINO GenAI | Works on NPU |
| `smollm2:135m` | 135M | Ollama | Tiny, extremely fast |

### Choosing the Right Size (32GB RAM)

- **0.5B–3B** — comfortable, leaves RAM free
- **7B Q4_K_M** — ideal balance, ~5GB RAM
- **13B Q4_K_M** — feasible, ~9GB RAM
- **32B Q4_K_M** — possible but slow on CPU (~18GB RAM)
- **70B+** — not practical without discrete GPU

---

## 💡 Tips

```bash
# Check disk usage
ls -lh ~/Models/
du -sh ~/Models/*

# Check what's running
ollama ps
curl http://localhost:8081/v1/models   # llama-server models
curl http://localhost:8080             # Open WebUI status
```