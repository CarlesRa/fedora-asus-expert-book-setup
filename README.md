# 🐧 Linux Asus ExpertBook Setup

![Fedora](https://img.shields.io/badge/Fedora-43-blue?logo=fedora&logoColor=white)
![Wayland](https://img.shields.io/badge/Wayland-1.22-lightgrey)
![Intel](https://img.shields.io/badge/Intel-Core_Ultra_200H-lightblue)

> **Target device:** Asus ExpertBook B5405CCA  
> **Platform:** Intel Core Ultra 7 255H (Arrow Lake-H)

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
| **CPU** | Intel Core Ultra 7 255H (Arrow Lake-H) |
| **GPU** | Intel Arc Graphics (ARL) — Device ID 0x7dd1 — ~21 GiB shared VRAM |
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

> On Fedora 43, the `render` group is usually assigned to the user by default, so the `usermod` step may not be strictly necessary. This section is a **recommended verification** to confirm the NPU device is visible before creating the container. The full AI stack (OpenVINO, Ollama, llama.cpp, Open WebUI) runs inside a Distrobox Ubuntu container — nothing else needs to be installed on the host.

---

## 🤖 3. Local AI Inference

> **Recommended approach: Distrobox Ubuntu container.** Running the full Intel AI stack inside an Ubuntu 24.04 container gives access to the complete `.deb` ecosystem — including NPU support — with **zero performance overhead** and a clean Fedora host.

### Performance Benchmarks (measured on Core Ultra 7 255H)

> CPU and Vulkan benchmarks below use the CPU-only / Vulkan builds. SYCL benchmarks (June 2026) use a separate `llama-cpp-sycl` container — see [3.3.1](#331-sycl-igpu-acceleration-via-intel-oneapi).

| Build | Model | Size | Prompt | Generation |
|-------|-------|------|--------|------------|
| llama.cpp CPU | Qwen 2.5 0.5B Q4_K_M | 0.5B | 185.9 t/s | 56.0 t/s |
| llama.cpp CPU | Gemma 4 E2B Q4_K_M | 2B | 46.3 t/s | 15.4 t/s |
| llama.cpp CPU | Gemma 4 E4B Q4_K_M | 4B | — | ~8 t/s |
| llama.cpp + Vulkan | Qwen 2.5 0.5B Q4_K_M | 0.5B | 86.1 t/s | 16.7 t/s |
| llama.cpp + Vulkan | Gemma 4 E2B Q4_K_M | 2B | 75.1 t/s | 6.9 t/s |
| llama.cpp + Vulkan | Gemma 4 E4B Q4_K_M | 4B | 48.2 t/s | 5.3 t/s |
| llama.cpp + Vulkan | Gemma 2 9B Q4_K_M | 9B | 29.2 t/s | 3.7 t/s |
| llama.cpp + SYCL (`-ngl 99`) | Qwen3 0.6B BF16 | 0.6B | 919.6 t/s | 24.3 t/s |
| llama.cpp + SYCL (`-ngl 0`, CPU) | Qwen3 0.6B BF16 | 0.6B | 648.0 t/s | 24.2 t/s |
| llama.cpp + SYCL (`-ngl 99`) | Gemma 4 E4B Q4_K_M | 7.5B | 178.9 t/s | 9.0 t/s |
| llama.cpp + SYCL (`-ngl 0`, CPU) | Gemma 4 E4B Q4_K_M | 7.5B | 138.5 t/s | 8.9 t/s |
| OpenVINO GenAI | NPU | — | — | ~6 t/s |

> ⚠️ **Key finding (Vulkan, April 2026):** Vulkan (iGPU) is **slower than CPU-only** for all model sizes on this hardware. The Intel iGPU uses shared RAM with limited memory bandwidth — the CPU accesses it faster directly.
>
> ⚠️ **Key finding (SYCL, June 2026):** Tested in a Ubuntu 24.04 distrobox container with Intel's `compute-runtime` (26.14.x, built from GitHub — the Ubuntu repo version is too old for Arrow Lake) and the oneAPI Base Toolkit. Same pattern as Vulkan, with a nuance:
> - **Prompt processing (`pp512`) is genuinely faster on GPU** — +29% on Gemma 4 E4B, +42% on Qwen3 0.6B, both reproducible across two very different model sizes/formats.
> - **Text generation (`tg128`) shows no real improvement** — within margin of error in both tests (Gemma 4 E4B: 8.99 vs 8.90 t/s; Qwen3 0.6B: 24.31 vs 24.19 t/s).
> - This confirms the bottleneck is memory bandwidth, not compute: prompt processing is parallelizable and compute-bound (GPU wins), while token-by-token generation is bandwidth-bound on shared RAM (GPU and CPU tie).
> - **Practical takeaway:** SYCL is worth enabling if your workload involves long prompts / RAG / large context (faster `pp512`), but offers no benefit for plain interactive chat, where generation speed (`tg128`) is what you feel.

### Recommended models for this hardware

| Use case | Model | Generation |
|----------|-------|------------|
| Fast & lightweight | Qwen 2.5 0.5B Q4_K_M | ~56 t/s |
| Best quality/speed balance ⭐ | Gemma 4 E2B Q4_K_M | ~15 t/s |
| Maximum quality | Gemma 4 E4B Q4_K_M | ~8 t/s |
| Long-prompt / RAG workloads | Any model + SYCL `-ngl 99` | +30–40% faster prompt ingestion |

---

### 3.0 Model Sourcing: Where to get models

| Source | Format | Best for... | Recommended Repos/Users |
|--------|--------|-------------|------------------------|
| [Hugging Face](https://huggingface.co) | `.gguf` | llama.cpp / Ollama. Single-file, easy to use, optimized for CPU | [bartowski](https://huggingface.co/bartowski), [MaziyarPanahi](https://huggingface.co/MaziyarPanahi), [mradermacher](https://huggingface.co/mradermacher) |
| [Hugging Face](https://huggingface.co) | `.safetensors` | OpenVINO / Transformers. Official "raw" weights. Requires conversion | [google (Gemma)](https://huggingface.co/google), [meta-llama](https://huggingface.co/meta-llama), [mistralai](https://huggingface.co/mistralai) |
| [Ollama Library](https://ollama.com/library) | Managed | One-command setup. Automatic download and config | [ollama.com/library](https://ollama.com/library) |
| [Civitai](https://civitai.com) | `.safetensors` | Stable Diffusion / Flux. Image generation models only | — |

---

### 3.1 Container Overview

Dedicated containers isolate each tool's dependencies:

| Container | Purpose | Devices |
|-----------|---------|---------|
| `openvino-npu` | OpenVINO + NPU/GPU inference, Gemma 4 | `/dev/accel/accel0`, `/dev/dri` |
| `ollama` | Ollama service + Open WebUI | `/dev/dri` |
| `llama-cpp` | llama.cpp CPU build + llama-server | CPU only |
| `llama-cpp-sycl` *(new, June 2026)* | llama.cpp + SYCL (iGPU) build | `/dev/dri` |

> 💡 The home directory (`~`) is shared with the host across all containers — models placed in `~/Models/` are accessible from any container.

---

#### `openvino-npu` — OpenVINO + NPU

```bash
sudo dnf install distrobox podman

# Create the container with access to NPU (/dev/accel) and GPU (/dev/dri)
distrobox create \
  --name openvino-npu \
  --image ubuntu:24.04 \
  --additional-flags "--device /dev/accel/accel0 --device /dev/dri"

distrobox enter openvino-npu
```

Inside the container, install the full Intel AI stack:

```bash
sudo apt update && sudo apt install -y curl wget git python3 python3-pip cmake gcc g++ zstd libtbb12

# --- OpenVINO 2026.x via Intel APT repo ---
wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
sudo apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
echo "deb https://apt.repos.intel.com/openvino ubuntu24 main" | \
  sudo tee /etc/apt/sources.list.d/intel-openvino.list
sudo apt update
sudo apt install -y openvino

# --- Intel GPU compute runtime (enables GPU in OpenVINO) ---
sudo apt install -y intel-opencl-icd intel-level-zero-gpu

# --- Intel NPU user-space driver v1.32.1 ---
mkdir -p /tmp/npu-driver && cd /tmp/npu-driver
wget https://github.com/intel/linux-npu-driver/releases/download/v1.32.1/linux-npu-driver-v1.32.1.20260422-24767473183-ubuntu2404.tar.gz
tar -xf linux-npu-driver-v1.32.1.20260422-24767473183-ubuntu2404.tar.gz
sudo dpkg -i intel-fw-npu_*.deb intel-driver-compiler-npu_*.deb intel-level-zero-npu_*.deb
cd ~ && rm -rf /tmp/npu-driver
```

### Verify all devices are detected

```bash
python3 -c "
import openvino as ov
core = ov.Core()
print('OpenVINO version:', ov.__version__)
print('Devices:', core.available_devices)
"
# Expected: Devices: ['CPU', 'GPU', 'NPU']
```
---

### 3.2 Ollama (inside `ollama`)

```bash
# Create the container (GPU device access for future acceleration)
distrobox create \
  --name ollama \
  --image ubuntu:24.04 \
  --additional-flags "--device /dev/dri"

distrobox enter ollama
```

```bash
# Inside the container
sudo apt update && sudo apt install -y curl

curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama service (keep running in background or a dedicated terminal)
ollama serve &

# Pull recommended models
ollama pull qwen2.5:0.5b
ollama pull gemma3:4b

# Export binary to host (run once — makes 'ollama' available on the host shell)
distrobox-export --bin /usr/local/bin/ollama
```

---

### 3.2.1 Ollama + Podman (Intel iGPU Acceleration)

For users who prefer a simpler deployment than compiling **llama.cpp**, Ollama can run inside a **Podman** container and access the Intel iGPU directly through **/dev/dri**.

#### CPU-only Container

```bash
podman run -d \
  --name ollama-intel \
  --device /dev/dri \
  --group-add keep-groups \
  -v ollama_storage:/root/.ollama \
  -p 11434:11434 \
  docker.io/ollama/ollama
```

#### Intel iGPU Accelerated Container

```bash
podman run -d \
  --name ollama-intel \
  --device /dev/dri:/dev/dri \
  --security-opt label=disable \
  --ipc=host \
  -e OLLAMA_INTEL_GPU=1 \
  -e ONEAPI_DEVICE_SELECTOR=level_zero \
  -v ollama_storage:/root/.ollama \
  -p 11434:11434 \
  docker.io/ollama/ollama
```

#### View Container Logs

```bash
podman logs ollama-intel
```

#### Download and Run a Test Model

```bash
podman exec -it ollama-intel ollama run phi3
```

The first execution automatically downloads the model into the persistent `ollama_storage` volume.

#### Verify GPU Utilization

In another terminal, monitor Intel GPU activity:

```bash
sudo intel_gpu_top
```

During model loading and inference, you should observe activity on the **Compute** engine. This confirms that Ollama is successfully utilizing the Intel iGPU rather than falling back entirely to CPU execution.

#### Notes

- `--device /dev/dri` exposes the Intel graphics device to the container.
- `OLLAMA_INTEL_GPU=1` enables Intel GPU acceleration in recent Ollama builds.
- `ONEAPI_DEVICE_SELECTOR=level_zero` forces the Level Zero backend, which generally provides better performance and compatibility on modern Intel GPUs than OpenCL.
- `--ipc=host` helps prevent shared-memory bottlenecks when loading larger models.
- Models remain persistent across container recreations through the `ollama_storage` volume.

#### Recommended Usage

This deployment method is ideal for local AI assistants, coding agents, RAG pipelines, and automation frameworks. It provides Intel GPU acceleration while retaining Ollama's straightforward model management workflow, eliminating the need to maintain a custom `llama.cpp` build.

---

### 3.3 llama.cpp — CPU-only build (inside `llama-cpp`)

```bash
# Create the container (CPU only — no device passthrough needed)
distrobox create \
  --name llama-cpp \
  --image ubuntu:24.04

distrobox enter llama-cpp
```

> **CPU-only is faster than Vulkan on this hardware** for text generation. The Intel iGPU shares RAM bandwidth with the CPU — the CPU accesses it more efficiently for token-by-token generation. See [3.3.1](#331-sycl-igpu-acceleration-via-intel-oneapi) for the SYCL nuance: GPU *does* help with prompt processing.

```bash
# Inside the container
cd ~/Projects
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp

# Build CPU-only (fastest for generation on this hardware)
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

Vulkan was tested extensively. Despite offloading all 43/43 layers to the Intel iGPU (`Intel Graphics ARL`, ~21 GiB shared VRAM), performance was **consistently worse than CPU-only** across all model sizes. The bottleneck is memory bandwidth — the iGPU shares RAM with the CPU and accesses it through a slower internal bus. CPU-only build wins on this hardware for token generation.

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

### 3.3.1 SYCL (iGPU acceleration via Intel oneAPI) — *added June 2026*

> 🆕 **New finding:** The SYCL backend genuinely speeds up **prompt processing** on the iGPU (+29% to +42% measured). When optimized with correct batching parameters and fully offloaded, it dynamically utilizes the Intel graphics hardware (~96% load via `intel_gpu_top`), making it highly capable of digesting massive developer contexts without freezing.

Tested inside a **separate distrobox container** (`ubuntu:24.04`), since SYCL needs the Intel oneAPI Base Toolkit and a newer `compute-runtime` than what ships in the Ubuntu repos.

```bash
distrobox create \
  --name llama-cpp-sycl \
  --image ubuntu:24.04 \
  --additional-flags "--device /dev/dri"

distrobox enter llama-cpp-sycl
```

#### Verify the iGPU is visible inside the container

```bash
ls -la /dev/dri

# Expect cardN and renderD12X with group-writable permissions
```

#### Install an up-to-date Intel compute-runtime (critical step)

⚠️ The `intel-opencl-icd` package from the Ubuntu 24.04 repos (23.43.x) is too old to recognize Arrow Lake / Meteor Lake iGPUs. `clinfo` will report `Number of platforms: 0` until you install a recent build directly from GitHub.

```bash
sudo apt update
sudo apt install -y clinfo
sudo apt remove -y intel-opencl-icd   # remove the stale Ubuntu repo version

mkdir -p ~/intel-compute-runtime && cd ~/intel-compute-runtime

# Intel Graphics Compiler (IGC) — check
# https://github.com/intel/intel-graphics-compiler/releases
# for the latest tag

wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.32.7/intel-igc-core-2_2.32.7+21184_amd64.deb
wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.32.7/intel-igc-opencl-2_2.32.7+21184_amd64.deb

# Compute Runtime — check
# https://github.com/intel/compute-runtime/releases
# for the latest tag

wget https://github.com/intel/compute-runtime/releases/download/26.14.37833.4/intel-opencl-icd_26.14.37833.4-0_amd64.deb
wget https://github.com/intel/compute-runtime/releases/download/26.14.37833.4/libigdgmm12_22.9.0_amd64.deb
wget https://github.com/intel/compute-runtime/releases/download/26.14.37833.4/libze-intel-gpu1_26.14.37833.4-0_amd64.deb
wget https://github.com/intel/compute-runtime/releases/download/26.14.37833.4/intel-ocloc_26.14.37833.4-0_amd64.deb

sudo dpkg -i *.deb
sudo apt-get install -f -y
```

#### Verify the GPU is now detected over OpenCL

```bash
clinfo | grep -i "Device Name"

# Expect: Device Name    Intel(R) Graphics
```

#### Install the Intel oneAPI Base Toolkit (provides SYCL + the icx/icpx compilers)

```bash
wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" \
  | sudo tee /etc/apt/sources.list.d/oneAPI.list

sudo apt update
sudo apt install -y intel-oneapi-base-toolkit
```

#### Build llama.cpp with SYCL

```bash
source /opt/intel/oneapi/setvars.sh

cd ~/Projects
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp

rm -rf build

cmake -B build \
  -DGGML_SYCL=ON \
  -DCMAKE_C_COMPILER=icx \
  -DCMAKE_CXX_COMPILER=icpx \
  -DCMAKE_BUILD_TYPE=Release

cmake --build build --config Release -j$(nproc)
```

#### Verify the device shows up

```bash
source /opt/intel/oneapi/setvars.sh

./build/bin/llama-cli --list-devices

# Expect:
# SYCL0: Intel(R) Graphics (XXXXX MiB, XXXX MiB free)
```

#### Auto-source oneAPI on shell start (avoid repeating source every session)

```bash
echo 'source /opt/intel/oneapi/setvars.sh > /dev/null 2>&1' >> ~/.bashrc
```

#### Run llama-server (Optimized for Agent Frameworks & OpenCode)

Coding agents and localized automation setups inject massive system contexts (frequently exceeding 12,000 tokens) to parse trees and tools. To prevent standard execution boundaries from rejecting the payloads, scale the sequence limit with an expanded context size (`-c 16384`), high execution batching (`-b 1024`), and anchor all layers directly into the iGPU compute space (`-ngl 99`):

```bash
./build/bin/llama-server \
  -m ~/Models/qwen2.5-coder-7b-instruct-q4_k_m.gguf \
  --port 8081 \
  -c 16384 \
  -ngl 99 \
  -b 1024
```

#### Benchmark results (this container, June 2026)

```bash
./build/bin/llama-bench \
  -m ~/Models/google_gemma-4-E4B-it-Q4_K_M.gguf \
  -ngl 99   # GPU

./build/bin/llama-bench \
  -m ~/Models/google_gemma-4-E4B-it-Q4_K_M.gguf \
  -ngl 0    # CPU (same binary)
```

| Model | Backend | pp512 | tg128 |
|---------|---------|---------|---------|
| Qwen3 0.6B BF16 | SYCL, `-ngl 99` (GPU) | 919.57 ± 75.80 t/s | 24.31 ± 0.20 t/s |
| Qwen3 0.6B BF16 | SYCL, `-ngl 0` (CPU) | 647.99 ± 5.67 t/s | 24.19 ± 0.14 t/s |
| Gemma 4 E4B Q4_K_M | SYCL, `-ngl 99` (GPU) | 178.89 ± 3.57 t/s | 8.99 ± 0.20 t/s |
| Gemma 4 E4B Q4_K_M | SYCL, `-ngl 0` (CPU) | 138.50 ± 0.52 t/s | 8.90 ± 0.14 t/s |

Verified live with `intel_gpu_top` during the GPU run: Compute/0 engine at ~97% busy and Blitter/0 at 100%, confirming the iGPU is genuinely doing the work rather than silently falling back to CPU.

**Takeaway:** Offload to iGPU via SYCL utilizing `-ngl 99`, `-c 16384`, and `-b 1024` if your application framework handles deep localized indexations (RAG, codebases, file trees). This prevents hardware fallback drops and handles massive multi-token dispatches natively.
---

### 3.4 Open WebUI (inside `ollama`)

A full-featured ChatGPT-like interface with built-in RAG support (upload PDFs, documents, web pages as context).

```bash
# Inside the container
pip install open-webui --break-system-packages
```

---

### 3.5 OpenVINO GenAI + NPU (inside `openvino-npu`)

> ⚠️ **Dependency conflict warning:** Open WebUI installs `transformers 5.x`. Use a separate venv to avoid breaking the main environment:

```bash
python3 -m venv ~/venv-openvino
source ~/venv-openvino/bin/activate
```

#### 3.5.1 Gemma 4 with optimum-intel (recommended)

Gemma 4 requires the main branch of both `transformers` and `optimum-intel` — the PyPI releases do not support `gemma4` yet (as of May 2026):

```bash
source ~/venv-openvino/bin/activate

# transformers from source — required for gemma4 model type support
pip install "git+https://github.com/huggingface/transformers.git" --upgrade

# optimum-intel from source — required for OVModelForVisualCausalLM
pip install "git+https://github.com/huggingface/optimum-intel.git@main" --upgrade

pip install torchvision Pillow requests
```

Download the pre-converted OpenVINO model (int4, ~2.5 GB):

```bash
pip install huggingface_hub
huggingface-cli download OpenVINO/gemma-4-E4B-IT-int4-ov --local-dir ~/Models/gemma-4-E4B-int4-ov
```

Run inference on CPU via OpenVINO:

```python
from optimum.intel.openvino import OVModelForVisualCausalLM
from transformers import AutoProcessor

model_path = "/home/<user>/Models/gemma-4-E4B-int4-ov"

processor = AutoProcessor.from_pretrained(model_path)
model = OVModelForVisualCausalLM.from_pretrained(model_path)

messages = [{"role": "user", "content": [{"type": "text", "text": "Explain AI in 2 sentences."}]}]
text = processor.apply_chat_template(messages, add_generation_prompt=True)
inputs = processor(text=text, return_tensors="pt")
input_len = inputs["input_ids"].shape[-1]

output = model.generate(**inputs, max_new_tokens=100, do_sample=False)
print(processor.decode(output[0][input_len:], skip_special_tokens=True))
```

> ℹ️ `openvino_genai.VLMPipeline` does **not** work with Gemma 4. The correct class is `OVModelForVisualCausalLM` from `optimum.intel.openvino`.

See `scripts/test-gemma4.py` in this repo for the full ready-to-run script.

#### 3.5.2 Qwen with openvino-genai on NPU

```bash
source ~/venv-openvino/bin/activate
pip install "transformers==4.45.0" openvino-genai "optimum[openvino]" optimum-intel
```

```bash
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
distrobox list                           # List all containers
distrobox stop llama-cpp                 # Stop a container
distrobox rm llama-cpp                   # Remove a container
distrobox enter llama-cpp -- htop        # Run a single command without entering the shell
distrobox enter ollama -- ollama list    # List downloaded Ollama models
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
- OpenVINO GenAI on NPU — blocked by version mismatch: Fedora ships OpenVINO 2025.1 but `openvino-genai` pip only distributes 2025.4+, which requires `libopenvino.so.2541`. Intel has no RPM repo for that version.

> **Update (May 2026):** This version mismatch is fully resolved inside the Distrobox container. Installing OpenVINO via Intel's APT repo (`apt.repos.intel.com/openvino ubuntu24`) gives OpenVINO 2026.1.0, which is compatible with the latest `openvino-genai` pip package. No workarounds needed.

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

### June 2026
✅ **SYCL iGPU backend tested for llama.cpp:** New `llama-cpp-sycl` distrobox container built with Intel oneAPI Base Toolkit + `-DGGML_SYCL=ON`. `--list-devices` correctly reports the Arrow Lake-P iGPU (`SYCL0: Intel(R) Graphics`).
✅ **Stale Ubuntu compute-runtime identified as root cause of "0 platforms":** The `intel-opencl-icd` package in Ubuntu 24.04 repos (23.43.x) doesn't recognize Arrow Lake/Meteor Lake iGPUs. Fixed by installing a current `compute-runtime` (26.14.x) + IGC (2.32.7) directly from Intel's GitHub releases.
✅ **Benchmarked SYCL vs CPU on two models:** Qwen3 0.6B BF16 and Gemma 4 E4B Q4_K_M, same binary, `-ngl 99` vs `-ngl 0`.
✅ **Key finding — SYCL helps prompt processing, not generation:** `pp512` is +29% to +42% faster on GPU (compute-bound, parallelizable). `tg128` ties with CPU within margin of error in both tests (bandwidth-bound, shared RAM). Same root cause documented for Vulkan in April 2026, but unlike Vulkan, SYCL does deliver a real win on the prompt-processing side.
✅ **Verified GPU utilization with `intel_gpu_top`:** Confirmed `Compute/0` engine at ~97% busy during SYCL inference, ruling out silent CPU fallback.
✅ **Practical guidance added:** Use SYCL `-ngl 99` for RAG / long-context / document-heavy workloads. Stick to the CPU-only build (section 3.3) for plain interactive chat, where generation speed is what matters and SYCL offers no advantage.

### May 2026
✅ **Gemma 4 running via OpenVINO + optimum-intel:** `gemma-4-E4B-IT-int4-ov` (pre-converted OpenVINO int4 model) runs successfully using `OVModelForVisualCausalLM` from `optimum-intel`. Inference confirmed on CPU via OpenVINO.
✅ **transformers from source required:** The `gemma4` model type is not supported in any PyPI release of `transformers` as of May 2026. Must install `transformers==5.8.0.dev0` from the GitHub main branch.
✅ **optimum-intel from source required:** PyPI `optimum-intel` pins `transformers<5.1`, breaking compatibility. Install from the GitHub main branch to get `OVModelForVisualCausalLM` working with Gemma 4.
✅ **`openvino_genai.VLMPipeline` does NOT work for Gemma 4:** Documented explicitly. The correct approach is `OVModelForVisualCausalLM` from `optimum.intel.openvino`.
✅ **`scripts/test-gemma4.py` added:** Ready-to-run script demonstrating Gemma 4 inference with OpenVINO.
✅ **Separate containers per tool:** Three dedicated Distrobox containers (`openvino-npu`, `ollama`, `llama-cpp`) isolate dependencies cleanly.
✅ **Correct OpenVINO install method:** Use Intel's official APT repo (`apt.repos.intel.com/openvino ubuntu24`) — not the Ubuntu 24.04 default repo (ships an old, broken OpenVINO build).
✅ **GPU compute runtime added:** `intel-opencl-icd` + `intel-level-zero-gpu` packages enable the Arc iGPU in OpenVINO.
✅ **NPU driver updated to v1.32.1:** New release from GitHub. Same 3-package install: `intel-fw-npu`, `intel-driver-compiler-npu`, `intel-level-zero-npu`.
✅ **Version mismatch resolved:** `openvino-genai` pip package now compatible with OpenVINO 2026.1.0 — no venv workaround needed for basic OpenVINO usage.

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