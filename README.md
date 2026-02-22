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
| **CPU** | Intel Core Ultra 7 (Meteor Lake / Arrow Lake) |
| **GPU** | Intel Graphics (Gen12 / Arc Architecture) |
| **NPU** | **Intel AI Boost** (Neural Processing Unit) - `intel_vpu` driver |
| **OS** | Fedora 43 – Workstation (Kernel 6.x+) |

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

### 2.1 Install the AI Stack (Level Zero)

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

(Log out and log back in to apply changes.)

### 2.3 Verify NPU Detection

```bash
python3 -c "from openvino.runtime import Core; print(Core().available_devices)"
```

Expected output:

```text
['CPU', 'GPU', 'NPU']
```

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

_(Your existing Distrobox section fits perfectly here — keep it as-is.)_

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

✅ **NPU Support:** Added OpenVINO 2025.1 and Level Zero drivers for Meteor/Arrow Lake.  
✅ **Fedora 43:** Updated package names for the intel-level-zero stack.  
✅ **Groups:** Documented `video,render` group requirements for NPU access.

---