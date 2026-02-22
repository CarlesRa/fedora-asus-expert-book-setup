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
4. [Local AI with Ollama (GPU)](#3-local-ai-with-ollama-gpu-accelerated)
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

## 🤖 3. Local AI with Ollama (GPU Accelerated)

> Note: Ollama currently uses the GPU (via OpenCL/Vulkan) or CPU.  
> To use the NPU, rely on the OpenVINO stack.

```bash
podman run -d \
  --name ollama \
  --device /dev/dri:/dev/dri \
  -v ollama-data:/root/.ollama \
  -p 11434:11434 \
  docker.io/ollama/ollama:latest
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
✅ **Groups:** Documented `video,render` group requirements for NPU access.

---