# 🐧 Linux Asus ExpertBook Setup

> **Target device:** Asus ExpertBook (Intel Core Ultra – Arrow Lake)

A curated, evolving guide for configuring **Linux on the Asus ExpertBook**, tested on **Fedora 43**. This setup prioritizes:

- ⚡ High performance  
- 🔋 Hardware longevity  
- 🧼 A clean, reproducible development workflow  

---

## 💻 Hardware Specifications

| Component   | Details                                             |
| ----------- | --------------------------------------------------- |
| **Device**  | Asus ExpertBook B5405CCA                            |
| **CPU**     | Intel Core Ultra 7 (Arrow Lake-P)                   |
| **GPU**     | Intel Integrated Graphics (Arrow Lake-P @ 2.25 GHz) |
| **NPU**     | Intel AI Boost (Neural Processing Unit)             |
| **RAM**     | 32 GB                                               |
| **Storage** | 1 TB NVMe SSD (Btrfs)                               |
| **OS**      | Fedora 43 – Workstation                             |
| **Desktop** | GNOME 49 (Wayland)                                  |

---

## ⚡ 1. GPU & Multimedia Optimization

Leverage **Arrow Lake media acceleration** to offload video decoding (YouTube, streaming, AV1) from the CPU, reducing heat and power usage.

### 1.1 Enable RPM Fusion Repositories

Fedora requires RPM Fusion for non-free codecs and Intel media drivers.

```bash
sudo dnf install \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
