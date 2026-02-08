# 🐧 Linux Asus ExpertBook Setup

![Fedora](https://img.shields.io/badge/Fedora-43-blue?logo=fedora&logoColor=white)
![Wayland](https://img.shields.io/badge/Wayland-1.22-lightgrey)
![Intel](https://img.shields.io/badge/Intel-Gen12-lightblue)

> **Target device:** Asus ExpertBook  
> **Platform:** Intel Core Ultra (Meteor Lake / Arrow Lake)

A curated, evolving guide for configuring **Linux on the Asus ExpertBook**, tested on **Fedora 43**.

This setup prioritizes:

- ⚡ **High performance** (GPU / NPU acceleration)
- 🔋 **Hardware longevity** (battery health)
- 🧼 **Clean, reproducible development workflow**

---

## 📑 Table of Contents

1. [Hardware Specifications](#hardware-specifications)
2. [GPU & Multimedia Optimization](#gpu--multimedia-optimization)
   - [Enable RPM Fusion](#enable-rpm-fusion-repositories)
   - [Video Acceleration & VA-API / OneVPL](#video-acceleration--modern-runtimes-va-api--onevpl)
   - [GPU Compute & OpenCL](#gpu-compute--opencl)
   - [Monitoring & Chrome Tweaks](#monitoring--chrome-tweaks)
3. [Development Workflow (Distrobox)](#development-workflow-distrobox)
4. [Infrastructure & Services (Podman Compose)](#infrastructure--services-podman-compose)
5. [Power & Battery Management (asusctl)](#power--battery-management-asusctl)
6. [Biometrics & Authentication](#biometrics--authentication)
7. [Local AI with Ollama (GPU Accelerated)](#local-ai-with-ollama-gpu-accelerated)
8. [Peripherals](#peripherals)
9. [Author](#author)
10. [Recent Changes](#recent-changes-february-2026)

---

## 💻 Hardware Specifications

| Component | Details |
|----------|---------|
| **Device** | Asus ExpertBook B5405CCA |
| **CPU** | Intel Core Ultra 7 (Meteor Lake / Arrow Lake) |
| **GPU** | Intel Graphics (Gen12 / Meteor Lake @ 2.25 GHz) |
| **NPU** | Intel AI Boost (Neural Processing Unit) |
| **RAM** | 32 GB |
| **Storage** | 1 TB NVMe SSD (Btrfs) |
| **OS** | Fedora 43 – Workstation |
| **Desktop** | GNOME 49 (Wayland) |

---

## ⚡ 1. GPU & Multimedia Optimization

Leverage **Intel Media acceleration** to offload video decoding (YouTube, streaming, AV1) from the CPU, reducing heat and power usage.

### 1.1 Enable RPM Fusion Repositories

```bash
sudo dnf install \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo dnf upgrade --refresh
```

### 1.2 Video Acceleration & Modern Runtimes (VA-API / OneVPL)

```bash
sudo dnf install \
  intel-media-driver \
  libva-intel-media-driver \
  intel-vpl-gpu-rt \
  libva-utils
```

### 1.3 GPU Compute & OpenCL

```bash
sudo dnf install \
  intel-compute-runtime \
  intel-opencl \
  intel-ocloc \
  intel-igc-libs
```

### 1.4 Monitoring & Chrome Tweaks

#### Tooling

```bash
sudo dnf install intel-gpu-tools
sudo intel_gpu_top
```

#### Chrome Flags

Enable in `chrome://flags`:

- GPU Rasterization  
- Zero-copy rasterizer  
- Hardware-accelerated video decode  

---

## 📦 2. Development Workflow (Distrobox)

Avoid polluting the host OS with multiple runtimes by using **Distrobox** containers.

### 2.1 Installation

```bash
sudo dnf install distrobox
```

### 2.2 VS Code Integration (“The Magic Bridge”)

```bash
# Inside your distrobox container
echo 'alias code="distrobox-host-exec code"' >> ~/.bashrc
source ~/.bashrc
```

✨ **Result:** Run `code .` from any containerized project folder while keeping binaries isolated.

---

## 🚀 3. Infrastructure & Services (Podman Compose)

| Layer | Technology | Purpose |
|-----|-----------|---------|
| Coding / Build | Distrobox | Angular, Node.js, Spring Boot, JDK |
| Infrastructure | Podman Compose | PostgreSQL, Redis, SonarQube |

```bash
sudo dnf install podman-compose
podman-compose up -d
```

---

## 🔋 4. Power & Battery Management (asusctl)

```bash
sudo dnf copr enable lukenukem/asus-linux
sudo dnf install asusctl
sudo systemctl enable --now asusd.service
```

Limit battery charge (recommended for docked laptops):

```bash
asusctl -c 60
```

---

## 🔐 5. Biometrics & Authentication

### Fingerprint Sensor
Native support via **Settings → Users**

### Face Recognition (Howdy – IR Camera)

```bash
sudo dnf copr enable principalis/howdy
sudo dnf install howdy
```

---

## 🧠 6. Local AI with Ollama (GPU Accelerated)

```bash
podman run -d \
  --name ollama \
  --device /dev/dri:/dev/dri \
  -v ollama-data:/root/.ollama \
  -p 11434:11434 \
  docker.io/ollama/ollama:latest
```

---

## ⌨️ 7. Peripherals

### Logitech MX Keys

```bash
sudo dnf install solaar
```

---

## ✍️ Author

**Juan Carlos Ramos Moll**  
GitHub: **[@CarlesRa](https://github.com/CarlesRa)**

---

## 🗓️ Recent Changes (February 2026)

- ✅ GPU Compute: Added OpenCL and Intel Compute Runtime support  
- ✅ VPL Integration: Configured `intel-vpl-gpu-rt` for Gen12+ architectures  
- ✅ Monitoring: Added `intel-gpu-tools` for real-time telemetry  
- ✅ VA-API: Verified 4K/60 fps hardware decoding on Fedora 43  
