# Linux Asus ExpertBook Setup

**Target device:** Asus ExpertBook (Intel Core Ultra)

This repository documents an evolving set of **Linux laptop configurations and experiments**, currently tested on an **Asus ExpertBook** running **Fedora 43**. It will be updated over time as new features, tweaks, and workflows are added, with a focus on:

* 🔐 **Biometric authentication** using the Infrared (IR) camera (FaceID via Howdy)
* 🧠 **Local AI inference** accelerated by Intel NPU (Intel AI Boost) using OpenVINO

The goal is a clean, reproducible setup suitable for daily use on a modern Linux laptop.

---

## 💻 Hardware Specifications

* **Device:** Asus ExpertBook
* **CPU:** Intel Core Ultra 7 255H (Lunar Lake / Arrow Lake)
* **GPU / NPU:** Intel Arc Graphics & Intel AI Boost (NPU)
* **Operating System:** Fedora 43 (Workstation Edition)

---

## 🎭 1. FaceID Integration (Howdy)

This section explains how to enable biometric authentication using the built-in **Infrared (IR) camera**.

### 1.1 Identify the IR Camera Device

First, determine which `/dev/video*` node corresponds to the IR camera. You can use either `guvcview` or `v4l-utils`.

```bash
sudo dnf install guvcview
```

Test the available video devices (commonly `/dev/video2` or `/dev/video3`) and identify the one that activates the **red IR LEDs**.

---

### 1.2 Install Howdy

Enable the COPR repository and install Howdy:

```bash
sudo dnf copr enable principalis/howdy
sudo dnf install howdy
```

---

### 1.3 Configure Howdy

Edit the configuration file and set the correct device path:

```ini
# /lib64/security/howdy/config.ini
device_path = /dev/video2  # Replace with your identified IR camera node
```

---

### 1.4 Enroll Your Face

Add your face to Howdy:

```bash
sudo howdy add
```

Follow the on-screen instructions to complete enrollment.

---

### 1.5 PAM Integration (Login & Sudo)

To enable FaceID for system login and sudo authentication, add the following line **at the top** of these files:

```text
auth sufficient pam_howdy.so
```

Files to modify:

* `/etc/pam.d/system-auth`
* `/etc/pam.d/gnome-screensaver`

> ⚠️ **Note:** Incorrect PAM configuration can lock you out of your system. Make sure you have a fallback TTY or SSH access before proceeding.

---

## 🧠 2. Local AI with NPU Acceleration (Intel OpenVINO)

To run Large Language Models (LLMs) efficiently without excessive power consumption, we leverage the **Intel NPU** via **OpenVINO** and **Podman**.

---

### 2.1 Prerequisites

Verify that the Intel VPU driver is loaded:

```bash
lsmod | grep intel_vpu
```

If the module is present, the NPU is available.

---

### 2.2 Deploy Ollama with Intel Acceleration

We use **Podman** to keep the host system clean and to access hardware acceleration via `/dev/dri`.

```bash
podman run -d \
  --name ollama-intel \
  --device /dev/dri:/dev/dri \
  -p 11434:11434 \
  -v ollama_data:/root/.ollama \
  docker.io/intel/ollama:latest
```

This setup enables GPU/NPU-backed inference while keeping everything containerized.

---

### 2.3 Monitoring Hardware Acceleration

To confirm that workloads are running on the GPU/NPU instead of the CPU:

```bash
sudo dnf install intel-gpu-tools
sudo intel_gpu_top
```

Look for activity in:

* **Compute engines**
* **NPU-related metrics** (if available)

---

## 🛠 Troubleshooting

### SELinux Issues

If Howdy fails to activate the camera during login, SELinux may be blocking access.

For testing purposes:

```bash
sudo setenforce 0
```

For a permanent solution, generate and apply a custom SELinux policy instead of disabling enforcement.

---

### FUSE Errors (AppImages)

Fedora 43 requires additional libraries to run AppImages (e.g. LM Studio):

```bash
sudo dnf install fuse-libs
```

---

## ✍️ Author

**Juan Carlos Ramos Moll (CarlesRa)**

---

⭐ If this repository helped you, consider starring it and contributing improvements.
