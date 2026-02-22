# 🐧 Linux Asus ExpertBook Setup

![Fedora](https://img.shields.io/badge/Fedora-43-blue?logo=fedora&logoColor=white)
![Wayland](https://img.shields.io/badge/Wayland-1.22-lightgrey)
![Intel](https://img.shields.io/badge/Intel-Core_Ultra-lightblue)

> **Target device:** Asus ExpertBook B5405CCA  
> **Platform:** Intel Core Ultra (Meteor Lake / Arrow Lake)

A curated, evolving guide for configuring **Linux on the Asus ExpertBook**, tested on **Fedora 43**.

This setup prioritizes:
- ⚡ **High performance** (GPU / NPU acceleration)
- 🔋 **Hardware longevity** (battery health)
- 🧠 **Local AI efficiency** (offloading LLMs to the NPU)

---

## 📑 Table of Contents
1. [Hardware Specifications](#hardware-specifications)
2. [GPU & Multimedia Optimization](#1-gpu--multimedia-optimization)
3. [NPU & AI Acceleration (OpenVINO)](#2-npu--ai-acceleration-openvino)
4. [Local AI Inference](#3-local-ai-inference)
5. [Development Workflow (Distrobox)](#4-development-workflow-distrobox)
6. [Power & Battery Management](#5-power--battery-management-asusctl)

---

## 💻 Hardware Specifications

| Component | Details |
|-----------|----------|
| **CPU** | Intel Core Ultra 7 255H (Meteor Lake) |
| **GPU** | Intel Graphics (Gen12 / Arc Architecture) |
| **NPU** | **Intel AI Boost** (Neural Processing Unit) - `intel_vpu` driver |
| **OS** | Fedora 43 – Workstation (Kernel 6.18+) |

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

## 🧠 2. NPU & AI Acceleration (OpenVINO)

To leverage the dedicated AI hardware (NPU) and free up the CPU/GPU during inference workloads (LLMs, Computer Vision).

### 2.1 Install the AI Stack

```bash
sudo dnf install \
  openvino \
  python3-openvino \
  intel-level-zero \
  oneapi-level-zero
```

### 2.2 Configure Hardware Permissions

Your user must belong to the acceleration groups:

```bash
sudo usermod -aG video,render $USER
```

Log out and log back in to apply changes. Verify with:

```bash
ls -la /dev/accel/accel0   # Should show group: render
groups | grep render        # Your user should appear
```

### 2.3 Install the NPU Userspace Driver

The NPU userspace driver (`intel-level-zero-npu`) is **not available in Fedora repos** and must be installed manually from Intel's GitHub releases.

> **Tested with:** [linux-npu-driver v1.28.0](https://github.com/intel/linux-npu-driver/releases/tag/v1.28.0)  
> Releases only ship `.deb` packages (Ubuntu), so we convert them for Fedora using `alien`.

```bash
# Install alien (deb → rpm converter)
sudo dnf install alien

# Download and extract the driver bundle
mkdir ~/Downloads/npu-driver && cd ~/Downloads/npu-driver
wget https://github.com/intel/linux-npu-driver/releases/download/v1.28.0/linux-npu-driver-v1.28.0.20251218-20347000698-ubuntu2404.tar.gz
tar -xf linux-npu-driver-v1.28.0.20251218-20347000698-ubuntu2404.tar.gz

# Convert only the two packages we need (skip intel-driver-compiler-npu — it conflicts with OpenVINO)
sudo alien --to-rpm intel-fw-npu_1.28.0.20251218-20347000698_ubuntu24.04_amd64.deb
sudo alien --to-rpm intel-level-zero-npu_1.28.0.20251218-20347000698_ubuntu24.04_amd64.deb

# Install (--replacefiles needed to avoid conflicts with base filesystem package)
sudo rpm -i --replacefiles intel-fw-npu-*.x86_64.rpm intel-level-zero-npu-*.x86_64.rpm
```

### 2.4 Fix Library Path (Fedora vs Ubuntu path mismatch)

The `.deb` packages install libraries to `/usr/lib/x86_64-linux-gnu/` (Ubuntu path).  
Fedora expects them in `/usr/lib64/`. Create symlinks:

```bash
sudo ln -s /usr/lib/x86_64-linux-gnu/libze_intel_npu.so.1.28.0 /usr/lib64/libze_intel_npu.so.1
sudo ln -s /usr/lib/x86_64-linux-gnu/libze_intel_npu.so.1.28.0 /usr/lib64/libze_intel_npu.so
```

Then make the path permanent for ldconfig:

```bash
echo "/usr/lib/x86_64-linux-gnu" | sudo tee /etc/ld.so.conf.d/intel-npu.conf
sudo ldconfig
```

### 2.5 Verify NPU Detection

```bash
python3 -c "from openvino import Core; print(Core().available_devices)"
```

Expected output:

```text
['CPU', 'GPU', 'NPU']
```

> ⚠️ The warning `Graph extension version from driver is 1.14. Larger than plugin max graph ext version 1.10` is harmless — it just means the driver is newer than what OpenVINO 2025.1 expects. NPU is fully functional.

---

## 🤖 3. Local AI Inference

Three options tested on this hardware, each with different tradeoffs:

| Option | Device | Speed | Notes |
|--------|--------|-------|-------|
| Ollama | CPU | ~3–5 tok/s | Easy setup, stable |
| llama.cpp | CPU | ~64 tok/s | Fast, GGUF models |
| OpenVINO GenAI | CPU / GPU | ✅ Working | Intel native stack |
| OpenVINO GenAI | NPU | ⏳ Blocked | See note below |

> **NPU inference blocked:** Fedora 43 ships OpenVINO 2025.1 but `openvino-genai` pip only distributes 2025.4+, which requires `libopenvino.so.2541`. Intel has no RPM repo for 2025.4. Will unblock when Fedora updates OpenVINO.

---

### 3.1 Ollama (Easy, CPU)

Vulkan support for Intel iGPU is experimental and generates corrupt output — CPU is the only stable option.

```bash
curl -fsSL https://ollama.com/install.sh | sh
sudo systemctl enable --now ollama
```

```bash
ollama pull qwen2.5:0.5b   # ~5 tokens/s, good for quick tests
ollama pull llama3.2        # ~3.6 tokens/s, more capable

ollama run qwen2.5:0.5b "hola"           # Single prompt
ollama run qwen2.5:0.5b                  # Interactive chat
ollama run qwen2.5:0.5b "hola" --verbose # Show tokens/s
ollama ps                                 # Show device being used
```

---

### 3.2 llama.cpp (Fast, CPU)

Significantly faster than Ollama on CPU (~64 tok/s vs ~5 tok/s). Uses GGUF models.

```bash
# Build from source
sudo dnf install cmake gcc g++ ninja-build
git clone https://github.com/ggerganov/llama.cpp ~/Projects/llama.cpp
cd ~/Projects/llama.cpp
cmake -B build
cmake --build build --config Release -j$(nproc)
```

```bash
# Download a GGUF model
wget https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf -P ~/Models/

# Run interactive mode
~/Projects/llama.cpp/build/bin/llama-cli \
  -m ~/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf \
  -n 200
```

---

### 3.3 OpenVINO GenAI (CPU + GPU)

Uses Intel's native inference stack. Requires converting models from HuggingFace to OpenVINO format first.

```bash
# Install dependencies
sudo dnf install python3-devel openvino-devel
pip install openvino-genai optimum[openvino] --break-system-packages

# Convert a model (downloads from HuggingFace and converts locally)
optimum-cli export openvino \
  --model Qwen/Qwen2.5-0.5B-Instruct \
  --weight-format int8 \
  ~/Models/qwen2.5-0.5b-openvino
```

```python
import openvino_genai as ov_genai

# CPU (stable)
pipe = ov_genai.LLMPipeline('~/Models/qwen2.5-0.5b-openvino', 'CPU')

# GPU — Intel iGPU (stable)
pipe = ov_genai.LLMPipeline('~/Models/qwen2.5-0.5b-openvino', 'GPU')

# NPU — blocked until Fedora updates OpenVINO to 2025.4+
# pipe = ov_genai.LLMPipeline('~/Models/qwen2.5-0.5b-openvino', 'NPU')

print(pipe.generate('hola, cómo estás?', max_new_tokens=50))
```

---

## 📦 4. Development Workflow (Distrobox)

[Distrobox](https://distrobox.it/) lets you run any Linux distro as a container fully integrated with the host — sharing your home directory, display, audio, and devices. Ideal for development environments that need different toolchains or package ecosystems without leaving Fedora.

### 4.1 Install

```bash
sudo dnf install distrobox podman
```

### 4.2 Create a Development Container

```bash
# Ubuntu 24.04 example (great for tools not packaged on Fedora)
distrobox create --name dev --image ubuntu:24.04

# Enter it
distrobox enter dev
```

Inside the container you have full `sudo` access and can install packages normally with `apt`. Your home directory (`~`) is shared with the host — files are the same on both sides.

### 4.3 Export an App to the Host

Once you've installed an app inside the container, you can make it available on the host as if it were installed natively:

```bash
# Run this from inside the container
distrobox-export --app firefox         # exports a GUI app (creates .desktop entry)
distrobox-export --bin /usr/bin/node   # exports a CLI binary
```

The exported binary appears at `~/.local/bin/` and the app shows up in your GNOME app launcher automatically.

> 💡 Useful for tools like `code`, `node`, `python3`, or any GUI app that's easier to install on Ubuntu than on Fedora.

### 4.4 Useful Commands

```bash
distrobox list                  # list all containers
distrobox stop dev              # stop a container
distrobox rm dev                # remove a container
distrobox enter dev -- htop     # run a single command without entering the shell
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

## 🗓️ Recent Changes (February 2026)

✅ **NPU Support:** Full step-by-step procedure to enable NPU on Fedora 43 using `alien` to convert Intel's Ubuntu `.deb` packages.  
✅ **Library path fix:** Documented symlink workaround for Ubuntu vs Fedora path mismatch (`/usr/lib/x86_64-linux-gnu` → `/usr/lib64`).  
✅ **OpenVINO 2025.1:** Verified working with `['CPU', 'GPU', 'NPU']` output.  
✅ **Local AI:** Documented three inference options (Ollama, llama.cpp, OpenVINO GenAI) with real measured performance.  
⏳ **NPU inference:** Blocked by OpenVINO version mismatch — tracked for future update.

---