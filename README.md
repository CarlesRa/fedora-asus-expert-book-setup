# 🐧 Linux Asus ExpertBook Setup

![Fedora](https://img.shields.io/badge/Fedora-43-blue?logo=fedora&logoColor=white)
![Wayland](https://img.shields.io/badge/Wayland-1.22-lightgrey)
![Intel](https://img.shields.io/badge/Intel-Core_Ultra-lightblue)

> **Target device:** Asus ExpertBook B5405CCA  
> **Platform:** Intel Core Ultra 7 255H (Meteor Lake)

A curated, evolving guide for configuring **Linux on the Asus ExpertBook**, tested on **Fedora 43**.

This setup prioritizes:
- ⚡ **High performance** (GPU / NPU acceleration)
- 🔋 **Hardware longevity** (battery health)
- 🧠 **Local AI efficiency** (offloading LLMs to the NPU)

---

## 📑 Table of Contents
1. [Hardware Specifications](#-hardware-specifications)
2. [GPU & Multimedia Optimization](#-1-gpu--multimedia-optimization)
3. [NPU Prerequisites (Host)](#-2-npu-prerequisites-host)
4. [Local AI Inference](#-3-local-ai-inference)
5. [Development Workflow (Distrobox)](#-4-development-workflow-distrobox)
6. [Power & Battery Management](#-5-power--battery-management-asusctl)
7. [Appendix: Host Installation Experience](#-appendix-host-installation-experience)

---

## 💻 Hardware Specifications

| Component | Details |
|-----------|----------|
| **CPU** | Intel Core Ultra 7 255H (Meteor Lake) |
| **GPU** | Intel Graphics (Gen12 / Arc Architecture) — ~21 GiB shared VRAM |
| **NPU** | Intel AI Boost — `intel_vpu` kernel driver |
| **OS** | Fedora 43 Workstation (Kernel 6.18+) |

---

## ⚡ 1. GPU & Multimedia Optimization

### 1.1 Video Acceleration & Compute

```bash
sudo dnf install \
  intel-media-driver \
  libva-intel-media-driver \
  intel-vpl-gpu-rt \
  intel-compute-runtime \
  intel-opencl
```

---

## 🧠 2. NPU Prerequisites (Host)

The NPU is managed by the `intel_vpu` kernel module, included in Fedora's kernel 6.18+. No compilation needed. The only host-level requirements are user group permissions and confirming the device node exists.

### 2.1 Hardware Permissions

```bash
sudo usermod -aG video,render $USER
# Log out and back in to apply
```

### 2.2 Verify the Device is Available

```bash
ls -la /dev/accel/accel0   # Should exist and show group: render
groups | grep render        # Your user should appear
lsmod | grep intel_vpu      # Kernel module should be loaded
```

Expected output:

```text
crw-rw-rw-. 1 root render 261, 0 ... /dev/accel/accel0
intel_vpu   360448  0
```

> The full AI stack (OpenVINO, Ollama, llama.cpp, Open WebUI) runs inside a Distrobox Ubuntu container — nothing else needs to be installed on the host.

---

## 🤖 3. Local AI Inference

> **Recommended approach: Distrobox Ubuntu container.** Running the full Intel AI stack inside an Ubuntu 24.04 container gives access to the complete `.deb` ecosystem — including NPU support — with **zero performance overhead** and a clean Fedora host.

### Performance Benchmarks (measured on Core Ultra 7 255H)

> All llama.cpp benchmarks use CPU-only build (no Vulkan). See findings below.

| Build | Model | Size | Prompt | Generation |
|-------|-------|------|--------|------------|
| llama.cpp CPU | Qwen 2.5 0.5B Q4_K_M | 0.5B | 185.9 t/s | 56.0 t/s |
| llama.cpp CPU | Gemma 4 E2B Q4_K_M | 2B | 46.3 t/s | 15.4 t/s |
| llama.cpp CPU | Gemma 4 E4B Q4_K_M | 4B | — | ~8 t/s |
| llama.cpp + Vulkan | Qwen 2.5 0.5B Q4_K_M | 0.5B | 86.1 t/s | 16.7 t/s |
| llama.cpp + Vulkan | Gemma 4 E2B Q4_K_M | 2B | 75.1 t/s | 6.9 t/s |
| llama.cpp + Vulkan | Gemma 4 E4B Q4_K_M | 4B | 48.2 t/s | 5.3 t/s |
| llama.cpp + Vulkan | Gemma 2 9B Q4_K_M | 9B | 29.2 t/s | 3.7 t/s |
| OpenVINO GenAI | NPU | — | — | ~6 t/s |

> ⚠️ **Key finding:** Vulkan (iGPU) is **slower than CPU-only** for all model sizes on this hardware. The Intel iGPU uses shared RAM with limited memory bandwidth — the CPU accesses it faster directly. **Use CPU-only build for best performance.**

### Recommended models for this hardware

| Use case | Model | Generation |
|----------|-------|------------|
| Fast & lightweight | Qwen 2.5 0.5B Q4_K_M | ~56 t/s |
| Best quality/speed balance ⭐ | Gemma 4 E2B Q4_K_M | ~15 t/s |
| Maximum quality | Gemma 4 E4B Q4_K_M | ~8 t/s |

---

### 3.0 Model Sourcing: Where to get models

| Source | Format | Best for... | Recommended Repos/Users |
|--------|--------|-------------|------------------------|
| [Hugging Face](https://huggingface.co) | `.gguf` | llama.cpp / Ollama. Single-file, easy to use, optimized for CPU | [bartowski](https://huggingface.co/bartowski), [MaziyarPanahi](https://huggingface.co/MaziyarPanahi), [mradermacher](https://huggingface.co/mradermacher) |
| [Hugging Face](https://huggingface.co) | `.safetensors` | OpenVINO / Transformers. Official "raw" weights. Requires conversion | [google (Gemma)](https://huggingface.co/google), [meta-llama](https://huggingface.co/meta-llama), [mistralai](https://huggingface.co/mistralai) |
| [Ollama Library](https://ollama.com/library) | Managed | One-command setup. Automatic download and config | [ollama.com/library](https://ollama.com/library) |
| [Civitai](https://civitai.com) | `.safetensors` | Stable Diffusion / Flux. Image generation models only | — |

---

### 3.1 Setup: Distrobox Ubuntu Container

```bash
sudo dnf install distrobox podman
distrobox create --name dev-ai --image ubuntu:24.04
distrobox enter dev-ai
```

Inside the container, install the Intel NPU driver stack:

```bash
sudo apt update && sudo apt install -y curl wget git python3 python3-pip cmake gcc g++ zstd libtbb12

# Intel NPU drivers
cd ~/Downloads
wget https://github.com/intel/linux-npu-driver/releases/download/v1.28.0/linux-npu-driver-v1.28.0.20251218-20347000698-ubuntu2404.tar.gz
tar -xf linux-npu-driver-v1.28.0.20251218-20347000698-ubuntu2404.tar.gz
sudo dpkg -i intel-fw-npu_*.deb intel-level-zero-npu_*.deb intel-driver-compiler-npu_*.deb

# Level Zero
wget https://github.com/oneapi-src/level-zero/releases/download/v1.24.2/level-zero_1.24.2+u24.04_amd64.deb
sudo dpkg -i level-zero_*.deb
```

---

### 3.2 Ollama (inside dev-ai)

```bash
# Inside the container
curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen2.5:0.5b
ollama pull llama3.2

# Export binary to host (run once)
distrobox-export --bin /usr/local/bin/ollama
```

---

### 3.3 llama.cpp — CPU-only build (inside dev-ai)

> **CPU-only is faster than Vulkan on this hardware.** The Intel iGPU shares RAM bandwidth with the CPU — the CPU accesses it more efficiently for LLM inference.

```bash
# Inside the container
cd ~/Projects
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp

# Build CPU-only (fastest for this hardware)
rm -rf build
cmake -B build
cmake --build build --config Release -j$(nproc)
```

> ⚠️ The build uses all CPU cores (~98% across all 16 threads) and takes several minutes — this is normal.

#### Export binaries to host (run once)

```bash
distrobox-export --bin /home/$USER/Projects/llama.cpp/build/bin/llama-cli
distrobox-export --bin /home/$USER/Projects/llama.cpp/build/bin/llama-server
```

#### Download models

```bash
# Fast model (~56 t/s)
wget https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf -P ~/Models/

# Best quality/speed balance (~15 t/s) ⭐ recommended
wget https://huggingface.co/bartowski/google_gemma-4-E2B-it-GGUF/resolve/main/google_gemma-4-E2B-it-Q4_K_M.gguf -P ~/Models/

# Maximum quality (~8 t/s)
wget https://huggingface.co/bartowski/google_gemma-4-E4B-it-GGUF/resolve/main/google_gemma-4-E4B-it-Q4_K_M.gguf -P ~/Models/
```

#### Run llama-server

```bash
# No -ngl flag — CPU only, fastest for this hardware
./build/bin/llama-server \
  -m ~/Models/google_gemma-4-E2B-it-Q4_K_M.gguf \
  --port 8081
```

#### Measure tokens per second

```bash
./build/bin/llama-cli \
  -m ~/Models/google_gemma-4-E2B-it-Q4_K_M.gguf \
  -p "Explain what artificial intelligence is in 3 paragraphs" \
  -n 200
# Look for: [ Prompt: XX.X t/s | Generation: XX.X t/s ]
```

#### About Vulkan (iGPU acceleration)

Vulkan was tested extensively. Despite offloading all 43/43 layers to the Intel iGPU (`Intel Graphics ARL`, ~21 GiB shared VRAM), performance was **consistently worse than CPU-only** across all model sizes. The bottleneck is memory bandwidth — the iGPU shares RAM with the CPU and accesses it through a slower internal bus. CPU-only build wins on this hardware.

To build with Vulkan if needed for future testing:

```bash
# Install Vulkan SDK first (provides glslc)
wget -qO- https://packages.lunarg.com/lunarg-signing-key-pub.asc | sudo tee /etc/apt/trusted.gpg.d/lunarg.asc
sudo wget -qO /etc/apt/sources.list.d/lunarg-vulkan-noble.list \
  https://packages.lunarg.com/vulkan/lunarg-vulkan-noble.list
sudo apt update
sudo apt install -y vulkan-sdk glslang-tools spirv-tools

# Build with Vulkan
rm -rf build
cmake -B build -DGGML_VULKAN=ON
cmake --build build --config Release -j$(nproc)
```

---

### 3.4 Open WebUI (inside dev-ai)

A full-featured ChatGPT-like interface with built-in RAG support (upload PDFs, documents, web pages as context).

```bash
# Inside the container
pip install open-webui --break-system-packages
```

---

### 3.5 OpenVINO GenAI + NPU (inside dev-ai)

> ⚠️ **Dependency conflict warning:** `optimum-intel` requires `transformers<4.58` but Open WebUI installs `transformers 5.x`. Use a separate venv to avoid breaking the main environment:

```bash
python3 -m venv ~/venv-openvino
source ~/venv-openvino/bin/activate
pip install "transformers==4.45.0" openvino-genai "optimum[openvino]" optimum-intel
```

```bash
# Convert model to OpenVINO format
source ~/venv-openvino/bin/activate
optimum-cli export openvino \
  --model Qwen/Qwen2.5-0.5B-Instruct \
  --weight-format int8 \
  ~/Models/qwen2.5-0.5b-openvino
```

```python
import openvino_genai as ov_genai

pipe = ov_genai.LLMPipeline('/home/<user>/Models/qwen2.5-0.5b-openvino', 'NPU')
print(pipe.generate('hola, cómo estás?', max_new_tokens=50))
# Note: first run is slow due to JIT compilation. Subsequent runs are faster.
```

---

### 3.6 Daily Usage — ai-start Script

A single script launches the full stack — presents a model selector, starts llama-server, and opens Open WebUI. Located at `scripts/ai-start.sh` in this repo.

```bash
chmod +x ~/Projects/fedora-asus-expert-book-setup/scripts/ai-start.sh
~/Projects/fedora-asus-expert-book-setup/scripts/ai-start.sh
```

Output:

```
📦 Available models:
1) google_gemma-4-E2B-it-Q4_K_M.gguf
2) qwen2.5-0.5b-instruct-q4_k_m.gguf
3) Cancel

Select a model: 1

🚀 Starting llama-server with google_gemma-4-E2B-it-Q4_K_M.gguf on port 8081...
   PID: 12769 — logs at /tmp/llama.log
🖥️  Starting Open WebUI at http://localhost:8080
   Press Ctrl+C to stop everything
```

Any `.gguf` file placed in `~/Models/` will appear in the selector automatically.

Make sure `~/.local/bin` is in your PATH (required for exported binaries):

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

In Open WebUI, go to **Admin Panel → Settings → Connections** and add an OpenAI-compatible connection (first time only):
- **URL:** `http://localhost:8081/v1`
- **API Key:** `llama` (any text)

---

## 📦 4. Development Workflow (Distrobox)

[Distrobox](https://distrobox.it/) runs any Linux distro as a container fully integrated with the host — sharing home directory, display, audio, and devices. No performance overhead vs native.

### 4.1 Install

```bash
sudo dnf install distrobox podman
```

### 4.2 Create a Container

```bash
distrobox create --name dev --image ubuntu:24.04
distrobox enter dev
```

Inside you have full `sudo` and `apt`. Your `~` is shared with the host.

### 4.3 Export to Host

Make apps or binaries available on the host without installing them natively:

```bash
# Inside the container
distrobox-export --app firefox          # GUI app → appears in GNOME launcher
distrobox-export --bin /usr/bin/node    # CLI binary → appears in ~/.local/bin/
```

> 💡 Make sure `~/.local/bin` is in your PATH: `echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc`

### 4.4 Useful Commands

```bash
distrobox list                   # List all containers
distrobox stop dev-ai            # Stop a container
distrobox rm dev-ai              # Remove a container
distrobox enter dev-ai -- htop   # Run a single command without entering the shell
```

---

## 🔋 5. Power & Battery Management (asusctl)

```bash
sudo dnf copr enable lukenukem/asus-linux
sudo dnf install asusctl
sudo systemctl enable --now asusd.service
asusctl -c 60   # Set battery charge limit to 60%
```

---

## 📎 Appendix: Host Installation Experience

During initial setup we attempted to install the full Intel AI stack directly on Fedora. Here is what we learned — useful context for anyone trying the same path.

**What works on host:**
- OpenVINO 2025.1 via `dnf` — CPU and GPU inference work fine
- NPU detection (`['CPU', 'GPU', 'NPU']`) — works after manual driver installation (see below)
- llama.cpp built from source — ~56 tok/s on CPU with Qwen 0.5B

**What doesn't work on host:**
- Ollama GPU acceleration — Vulkan support for Intel iGPU generates corrupt output
- OpenVINO GenAI on NPU — blocked by version mismatch: Fedora ships OpenVINO 2025.1 but `openvino-genai` pip only distributes 2025.4+, which requires `libopenvino.so.2541`. Intel has no RPM repo for 2025.4

**NPU driver workaround (host):**

Intel only ships `.deb` packages. We converted them to RPM using `alien` and fixed the library path mismatch with symlinks:

```bash
sudo dnf install alien
mkdir ~/Downloads/npu-driver && cd ~/Downloads/npu-driver
wget https://github.com/intel/linux-npu-driver/releases/download/v1.28.0/linux-npu-driver-v1.28.0.20251218-20347000698-ubuntu2404.tar.gz
tar -xf linux-npu-driver-v1.28.0.20251218-20347000698-ubuntu2404.tar.gz

sudo alien --to-rpm intel-fw-npu_*.deb intel-level-zero-npu_*.deb
sudo rpm -i --replacefiles intel-fw-npu-*.rpm intel-level-zero-npu-*.rpm

# Fix Ubuntu vs Fedora library path mismatch
sudo ln -s /usr/lib/x86_64-linux-gnu/libze_intel_npu.so.1.28.0 /usr/lib64/libze_intel_npu.so.1
sudo ln -s /usr/lib/x86_64-linux-gnu/libze_intel_npu.so.1.28.0 /usr/lib64/libze_intel_npu.so
echo "/usr/lib/x86_64-linux-gnu" | sudo tee /etc/ld.so.conf.d/intel-npu.conf
sudo ldconfig
```

This makes the NPU visible to OpenVINO, but `openvino-genai` still can't use it due to the version mismatch. **Conclusion: use Distrobox.**

---

## 🗓️ Recent Changes

### April 2026
✅ **CPU-only is fastest:** Extensive benchmarking confirmed CPU-only llama.cpp outperforms Vulkan (iGPU) on all model sizes. The Intel iGPU shares RAM bandwidth with the CPU and accesses it through a slower bus — CPU wins. Default build is now CPU-only.  
✅ **Vulkan tested and documented:** Vulkan build tested with Gemma 2 9B, Gemma 4 E2B/E4B, Qwen 0.5B. All models slower with Vulkan. Instructions preserved in section 3.3 for future reference as drivers improve.  
✅ **Gemma 4 benchmarked:** New Gemma 4 family (E2B, E4B) tested. Gemma 4 E2B Q4_K_M at ~15 t/s is the recommended daily driver — better quality than Gemma 2 9B at 4x the speed.  
✅ **Vulkan SDK setup documented:** LunarG repo + `glslc` install process documented for future use.  
✅ **Dependency conflict documented:** `optimum-intel` vs `transformers 5.x` conflict documented with venv workaround.

### February 2026
✅ **Distrobox AI stack:** Full Intel AI stack (Ollama, llama.cpp, OpenVINO GenAI + NPU, Open WebUI) running inside Ubuntu 24.04 container with zero performance overhead.  
✅ **Open WebUI:** ChatGPT-like interface with RAG support, connected to llama-server.  
✅ **NPU confirmed working:** OpenVINO GenAI on NPU via Distrobox at ~6 tok/s.  
✅ **llama.cpp:** ~56 tok/s on CPU with Qwen 0.5B, binaries exported to host via `distrobox-export`.  
✅ **ai-start.sh:** Single script to select model, launch llama-server and Open WebUI from host.  
✅ **Host experience documented:** Appendix covers what works and what doesn't when installing directly on Fedora.