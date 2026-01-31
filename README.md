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
| **Device**  | Asus ExpertBook B5405CCA                            |
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

Fedora requires RPM Fusion for non‑free codecs and Intel media drivers.

```bash
sudo dnf install \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
```

### 1.2 Video Acceleration Drivers (VA‑API)

Install the modern **Intel Media Driver**, supporting **H.264, HEVC, VP9, and AV1**.

```bash
sudo dnf install intel-media-driver libva-utils
```

✅ **Verification**

```bash
vainfo
```

You should see `VAProfileAV1Profile0` among the available profiles.

---

## 📦 2. Development Workflow (Distrobox)

Avoid polluting the host OS with multiple runtimes by using **Distrobox** containers that seamlessly share your `$HOME` directory.

### 2.1 Installation

```bash
sudo dnf install distrobox
```

### 2.2 Example: Angular Development Box

```bash
# Create and enter the container
distrobox create --name dev-angular --image fedora:43
distrobox enter dev-angular

# Install tooling inside the box
sudo dnf install nodejs npm git -y
sudo npm install -g @angular/cli
```

### 2.3 VS Code Integration ("The Magic Bridge")

Open **VS Code (installed on the host)** directly from inside the container using `code .`.

```bash
# Inside the distrobox
echo 'alias code="distrobox-host-exec code"' >> ~/.bashrc
source ~/.bashrc
```

✨ **Result:** Run `code .` from any containerized project folder while keeping binaries and tooling fully isolated.

---

## 🚀 3. Infrastructure & Services (Podman Compose)

Use a **hybrid model**: compilers and SDKs inside Distrobox, long‑running services on the host via Podman Compose.

| Layer          | Technology     | Purpose                            |
| -------------- | -------------- | ---------------------------------- |
| Coding / Build | Distrobox      | Angular, Node.js, Spring Boot, JDK |
| Infrastructure | Podman Compose | PostgreSQL, Redis, SonarQube       |

### Start Services (Host)

```bash
sudo dnf install podman-compose
podman-compose up -d
```

---

## 🔋 4. Power & Battery Management (asusctl)

Unlock Asus‑specific firmware features and battery protection.

### 4.1 Installation

```bash
sudo dnf copr enable lukenukem/asus-linux
sudo dnf install asusctl
sudo systemctl enable --now asusd.service
```

### 4.2 Battery Charge Limiting

Limit maximum charge to preserve battery health (recommended for docked laptops).

```bash
# Limit charge to 60%
asusctl -c 60
```

---

## 🔐 5. Biometrics & Authentication

* **Fingerprint Sensor**
  Native support via **Settings → Users**

* **Face Recognition (Howdy – Optional)**
  Enable IR camera authentication

```bash
sudo dnf copr enable principalis/howdy
sudo dnf install howdy
```

---

## 🧠 6. Local AI with Ollama (Intel iGPU)

Run local LLMs using **Intel GPU acceleration** via Podman.

```bash
podman run -d \
  --name ollama \
  --device /dev/dri/renderD128:/dev/dri/renderD128 \
  -v ollama-data:/root/.ollama \
  -p 11434:11434 \
  docker.io/ollama/ollama:latest
```

---

## ⌨️ 7. Peripherals (Logitech MX Keys)

Manage Logitech device pairing and battery levels.

```bash
sudo dnf install solaar
```

---

## ✍️ Author

**Juan Carlos Ramos Moll**
GitHub: **@CarlesRa**

---

## 🗓️ Recent Changes (January 2026)

* ✅ VA‑API configured with **AV1** support for Arrow Lake
* ✅ Integrated VS Code `host-exec` alias for seamless containerized development
* ✅ Hybrid workflow established: **Distrobox (Apps)** + **Podman Compose (Infrastructure)**
* ✅ Battery charge threshold set to **60%** for long‑term health

---

⭐ *If this setup helps you, consider starring the repository!*
