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
| **GPU** | Intel Graphics (Gen12 / Arc Architecture) |
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

> The full AI stack (OpenVINO, Ollama, llama.cpp) runs inside a Distrobox Ubuntu container — nothing else needs to be installed on the host.

---

## 🤖 3. Local AI Inference

> **Recommended approach: Distrobox Ubuntu container.** Running the full Intel AI stack inside an Ubuntu 24.04 container gives access to the complete `.deb` ecosystem — including NPU support — with **zero performance overhead** and a clean Fedora host.

### Performance Summary (measured on Core Ultra 7 255H)

| Tool | Device | Speed |
|------|--------|-------|
| Ollama | CPU | ~3–5 tok/s |
| llama.cpp | CPU | ~64 tok/s |
| OpenVINO GenAI | CPU / GPU | ✅ Working |
| OpenVINO GenAI | NPU | ~6 tok/s |

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

### 3.2 Ollama (inside dev-ai)

```bash
# Inside the container
curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen2.5:0.5b
ollama pull llama3.2

# Export binary to host (run once)
distrobox-export --bin /usr/local/bin/ollama
```

On the host, add an alias to start the server without entering the container:

```bash
echo 'alias ollama-serve="distrobox enter dev-ai -- bash -c \"ollama serve > /tmp/ollama.log 2>&1 &\""' >> ~/.bashrc
source ~/.bashrc
```

Daily usage from the host:

```bash
ollama-serve                              # Start Ollama server
ollama run qwen2.5:0.5b "hola"           # Run a model
ollama run qwen2.5:0.5b "hola" --verbose # Show tokens/s
ollama list                               # List downloaded models
ollama ps                                 # Show running models
```

### 3.3 llama.cpp (inside dev-ai)

Significantly faster than Ollama on CPU (~64 tok/s). Uses GGUF models.

```bash
# Inside the container — build from source
cd ~/Projects
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
cmake -B build
cmake --build build --config Release -j$(nproc)

# Export binary to host (run once)
distrobox-export --bin /home/$USER/Projects/llama.cpp/build/bin/llama-cli
```

Download a GGUF model (shared `~/Models` between host and container):

```bash
wget https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf -P ~/Models/
```

Daily usage from the host:

```bash
llama-cli -m ~/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf -n 200           # Interactive chat
llama-cli -m ~/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf -p "hola" -n 50  # Single prompt
```

### 3.4 OpenVINO GenAI + NPU (inside dev-ai)

```bash
# Inside the container
pip install openvino-genai optimum[openvino] --break-system-packages

# Convert model to OpenVINO format
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
- llama.cpp built from source — ~64 tok/s on CPU

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

## 🗓️ Recent Changes (February 2026)

✅ **Distrobox AI stack:** Full Intel AI stack (Ollama, llama.cpp, OpenVINO GenAI + NPU) running inside Ubuntu 24.04 container with zero performance overhead.  
✅ **NPU confirmed working:** OpenVINO GenAI on NPU via Distrobox at ~6 tok/s.  
✅ **llama.cpp:** ~64 tok/s on CPU, binary exported to host via `distrobox-export`.  
✅ **Ollama:** Exported to host, server started via alias without entering the container.  
✅ **Host experience documented:** Appendix covers what works and what doesn't when installing directly on Fedora.

---