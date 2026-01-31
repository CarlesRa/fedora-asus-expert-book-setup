# 🐧 Linux Asus ExpertBook Setup

> **Target device:** Asus ExpertBook (Intel Core Ultra – Arrow Lake)

A curated, evolving guide for configuring **Linux on the Asus ExpertBook**, tested on **Fedora 43**. This setup prioritizes:

* ⚡ High performance
* 🔋 Hardware longevity
* 🧼 A clean, reproducible development workflow

---

## 💻 Hardware Specifications

| Component   | Details                                             |
| ----------- | --------------------------------------------------- |
| **Device**  | Asus ExpertBook **B5405CCA**                        |
| **CPU**     | Intel Core Ultra 7 (Arrow Lake‑P)                   |
| **GPU**     | Intel Integrated Graphics (Arrow Lake‑P @ 2.25 GHz) |
| **NPU**     | Intel AI Boost (Neural Processing Unit)             |
| **RAM**     | 32 GB                                               |
| **Storage** | 1 TB NVMe SSD (Btrfs)                               |
| **OS**      | Fedora 43 – Workstation                             |
| **Desktop** | GNOME 49 (Wayland)                                  |

---

## ⚡ 1. GPU & Multimedia Optimization

Leverage **Arrow Lake media acceleration** to offload video decoding (YouTube, streaming, AV1) from the CPU, reducing heat and power usage.

### 1.1 Enable RPM Fusion Repositories

Required for non‑free codecs and Intel media drivers.

```bash
sudo dnf install \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
```

### 1.2 Video Acceleration Drivers (VA‑API)

Install the modern **Intel Media Driver** supporting **H.264, HEVC, VP9, and AV1**.

```bash
sudo dnf install intel-media-driver libva-utils
```

✅ **Verification**

```bash
vainfo
```

You should see multiple `VAEntrypointVLD` entries, including:

* `VAProfileAV1Profile0`

---

## 📦 2. Development Workflow (Distrobox)

Avoid polluting the host OS with multiple runtimes by using **Distrobox** containers that seamlessly share your `$HOME` directory.

### 2.1 Installation

```bash
sudo dnf install distrobox
```

### 2.2 Example: Angular Development Box

```bash
# Create a Fedora 43 container
distrobox create --name dev-angular --image fedora:43

# Enter the box and install tooling
distrobox enter dev-angular
sudo dnf install nodejs npm git -y
sudo npm install -g @angular/cli
```

### 2.3 VS Code Integration

1. Install **VS Code (RPM)** on the host
2. Open your project folder normally
3. In the integrated terminal, run:

```bash
distrobox enter dev-angular
```

✨ **Result:** Native UI performance + fully isolated toolchains

---

## 🔋 3. Power & Battery Management (asusctl)

Unlock Asus‑specific features such as performance profiles and battery protection.

### 3.1 Installation

```bash
sudo dnf copr enable lukenukem/asus-linux
sudo dnf install asusctl
sudo systemctl enable --now asusd.service
```

### 3.2 Battery Charge Limiting

Limit maximum charge to extend battery lifespan (recommended for docked laptops).

```bash
# Limit charge to 60%
asusctl -c 60
```

### 3.3 Performance Profiles

```bash
# Show active profile
asusctl profile get

# Cycle profiles (Performance / Balanced / Quiet)
asusctl profile -n
```

---

## 🔐 4. Biometrics & Authentication

* **Fingerprint Sensor**
  Supported natively via **Settings → Users** in Fedora 43

* **Face Recognition (Howdy – Optional)**
  Enable IR camera authentication

```bash
sudo dnf copr enable principalis/howdy
sudo dnf install howdy
```

---

## 🧠 5. Local AI with Ollama (Intel iGPU)

Run local LLMs using **Intel GPU acceleration** inside a Podman container.

```bash
podman run -d \
  --name ollama \
  --device /dev/dri/renderD128:/dev/dri/renderD128 \
  -v ollama-data:/root/.ollama \
  -p 11434:11434 \
  docker.io/ollama/ollama:latest
```

---

## ⌨️ 6. Peripherals (Logitech MX Keys)

Manage Logitech device pairing and battery levels.

```bash
sudo dnf install solaar
```

---

## ✍️ Author

**Juan Carlos Ramos Moll**
GitHub: **@CarlesRa**

---

## 🗓️ Recent Changes (January 2026)

* ✅ VA‑API configured with **AV1** support for Arrow Lake
* ✅ Distrobox workflow implemented for **Angular development**
* ✅ Battery charge threshold set to **60%** via `asusctl`
* ✅ Fedora 43 hardware compatibility fully verified

---

⭐ *If this setup helps you, consider starring the repo or adapting it to your own hardware!*
