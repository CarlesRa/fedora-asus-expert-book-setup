# Linux Asus ExpertBook Setup
**Target device:** Asus ExpertBook (Intel Core Ultra)

This repository documents an evolving set of **Linux laptop configurations and experiments**, currently tested on an **Asus ExpertBook** running **Fedora 43**. It will be updated over time as new features, tweaks, and workflows are added, with a focus on:
* 🔐 **Biometric authentication** using the Infrared (IR) camera (FaceID via Howdy)
* 🧠 **Local AI inference** using Ollama with Intel GPU acceleration
* 🐳 **Containerized deployments** via Podman for minimal system impact

The goal is a clean, reproducible setup suitable for daily use on a modern Linux laptop.

---

## 💻 Hardware Specifications
* **Device:** Asus ExpertBook B5405CCA
* **CPU:** Intel Core Ultra 7 255H (Arrow Lake-P, 16 cores @ 5.10 GHz)
* **GPU:** Intel Graphics (Arrow Lake-P integrated GPU @ 2.25 GHz)
* **NPU:** Intel AI Boost (Neural Processing Unit)
* **RAM:** 32 GB
* **Storage:** 1 TB NVMe SSD (btrfs)
* **Operating System:** Fedora 43 (Workstation Edition)
* **Desktop Environment:** GNOME 49.2 (Wayland)

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

## 🧠 2. Local AI with Ollama (Intel GPU Acceleration)

This setup runs **Ollama** in a Podman container with Intel GPU acceleration for local LLM inference. The deployment is **non-invasive** - everything runs containerized with minimal host system modifications.

### 2.1 Prerequisites

Verify Intel GPU access:
```bash
# Check DRI devices (GPU access)
ls -la /dev/dri/
# Should show card0/card1 and renderD128

# Verify Intel GPU is detected
lspci | grep -i vga
# Should show: Intel Corporation Arrow Lake-P [Intel Graphics]
```

**Optional monitoring tools:**
```bash
sudo dnf install intel-gpu-tools  # For intel_gpu_top monitoring
```

---

### 2.2 Deploy Ollama with Podman

#### Create storage for models
```bash
# Option 1: Using a local directory
mkdir -p ~/ollama-models

# Option 2: Using a Podman volume (recommended for SELinux)
podman volume create ollama-data
```

#### Run Ollama container with GPU access
```bash
# Using local directory (with SELinux label)
podman run -d \
  --name ollama \
  --device /dev/dri/card1:/dev/dri/card1 \
  --device /dev/dri/renderD128:/dev/dri/renderD128 \
  -v ~/ollama-models:/root/.ollama:Z \
  -p 11434:11434 \
  docker.io/ollama/ollama:latest

# OR using Podman volume
podman run -d \
  --name ollama \
  --device /dev/dri/card1:/dev/dri/card1 \
  --device /dev/dri/renderD128:/dev/dri/renderD128 \
  -v ollama-data:/root/.ollama \
  -p 11434:11434 \
  docker.io/ollama/ollama:latest
```

> **Note:** The `:Z` flag is important for SELinux contexts. Using Podman volumes avoids permission issues entirely.

---

### 2.3 Download and Run Models
```bash
# Pull a model (1B parameter model, ~700MB)
podman exec ollama ollama pull llama3.2:1b

# Run interactive chat
podman exec -it ollama ollama run llama3.2:1b

# List downloaded models
podman exec ollama ollama list

# Exit chat with: /bye
```

**Recommended models for testing:**
* `llama3.2:1b` - Smallest, fastest (700MB)
* `tinyllama:1.1b` - Very fast, less capable (637MB)
* `llama3.2:3b` - Better quality, slower (~2GB)
* `phi3:mini` - Optimized for Intel hardware

---

### 2.4 Using Ollama via API
```bash
# Generate text via HTTP API
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:1b",
  "prompt": "Explain quantum computing in simple terms",
  "stream": false
}'

# List available models via API
curl http://localhost:11434/api/tags
```

---

### 2.5 Monitoring GPU Usage
```bash
# Monitor Intel GPU activity in real-time
sudo intel_gpu_top

# Watch container resource usage
podman stats ollama
```

During inference, you should see activity in:
* **Render/3D engine** - GPU compute workload
* **Compute engine** - Additional acceleration

---

### 2.6 Container Management
```bash
# Stop Ollama
podman stop ollama

# Start Ollama
podman start ollama

# Remove container (keeps models if using volume)
podman rm ollama

# Remove downloaded models
podman exec ollama ollama rm llama3.2:1b

# View logs
podman logs ollama
```

---

### 2.7 Current Limitations & Future

**Current state (December 2024):**
* ✅ Intel **iGPU acceleration** works well
* ⚠️ Intel **NPU support** in Linux is still maturing
* ⚠️ Inference speed is moderate (acceptable for privacy-focused use cases)
* ✅ Fully containerized, zero host system pollution

**Expected improvements (2025-2026):**
* Native NPU drivers and OpenVINO integration
* Faster inference with dedicated NPU acceleration
* Better model optimization for Intel AI Boost

**Use cases where local AI excels:**
* 🔒 Complete privacy (offline, no cloud)
* 📡 Offline operation
* 🆓 Zero API costs after initial setup
* 🧪 Experimentation with fine-tuning, RAG, embeddings

---

## 🛠 Troubleshooting

### SELinux Issues with Howdy
If Howdy fails to activate the camera during login, SELinux may be blocking access.

For testing purposes:
```bash
sudo setenforce 0
```
For a permanent solution, generate and apply a custom SELinux policy instead of disabling enforcement.

---

### Podman Permission Errors
If you encounter `permission denied` errors with volumes:
```bash
# Option 1: Add :Z flag for SELinux labeling
-v ~/ollama-models:/root/.ollama:Z

# Option 2: Use Podman volumes (recommended)
podman volume create ollama-data
-v ollama-data:/root/.ollama

# Option 3: Adjust directory permissions (less secure)
chmod 777 ~/ollama-models
```

---

### FUSE Errors (AppImages)
Fedora 43 requires additional libraries to run AppImages (e.g. LM Studio):
```bash
sudo dnf install fuse-libs
```

---

### Slow AI Inference
Factors affecting performance:
* **Model size** - Smaller models (1B-3B params) are faster
* **Quantization** - Q4/Q8 models trade quality for speed
* **GPU frequency** - Check if GPU is throttled (thermal/power limits)
* **System load** - Background processes competing for resources

Try lighter models or quantized versions:
```bash
podman exec ollama ollama pull llama3.2:1b-q4_0
```

---

# 🔋 Battery Health & Power Management (Asusctl)

This section covers the installation of **asusctl**, a specialized utility for Asus laptops that enables power profile switching and, most importantly, battery charge limiting to extend hardware lifespan.

---

## 📦 Install Asus Utilities

Enable the specialized Asus Linux COPR repository and install the necessary tools for system control:

### For Fedora

```bash
# Add the COPR repository
sudo dnf copr enable lukenukem/asus-linux

# Install asusctl
sudo dnf install asusctl

# Enable and start the service
sudo systemctl enable --now asusd.service
```

### For Arch Linux / Manjaro

```bash
# Install from AUR
yay -S asusctl

# Enable services
sudo systemctl enable --now power-profiles-daemon.service
sudo systemctl enable --now asusd.service
```

### For Ubuntu / Debian

```bash
# Add repository
echo "deb [signed-by=/usr/share/keyrings/asus-linux.gpg] https://asus-linux.org/debian $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/asus-linux.list
sudo mkdir -p /usr/share/keyrings
wget -qO- https://asus-linux.org/debian/asus-linux.gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/asus-linux.gpg

# Install
sudo apt update
sudo apt install asusctl
sudo systemctl enable --now asusd.service
```

---

## ⚙️ Basic Configuration

### Performance Profiles

Asusctl allows switching between different profiles to optimize performance or battery life:

```bash
# List available profiles
asusctl profile -l

# Switch to quiet mode (power saving)
asusctl profile -P Quiet

# Switch to balanced mode
asusctl profile -P Balanced

# Switch to performance mode
asusctl profile -P Performance
```

### 🔌 Battery Charge Limiting

One of the most important features for battery longevity is limiting the maximum charge level:

```bash
# Limit charge to 80% (recommended for daily use)
asusctl -c 80

# Limit charge to 60% (optimal if always plugged in)
asusctl -c 60

# Full charge to 100% (only when you need maximum autonomy)
asusctl -c 100
```

### 📊 Check Status

```bash
# View current configuration
asusctl -s

# Complete system information
asusctl --help
```

---

## 💡 Tips to Maximize Battery Life

- **Daily use while plugged in**: Limit charge to 60-80%
- **Frequent mobile use**: Keep between 80-90%
- **Long trips**: Charge to 100% only when necessary
- **Long-term storage**: Leave battery at 50-60%

---

## 🎯 Result

With asusctl configured, you'll have complete control over the performance and battery health of your ASUS ExpertBook, significantly extending its lifespan.

## 📚 Additional Resources

* [Ollama Documentation](https://github.com/ollama/ollama/blob/main/README.md)
* [Intel GPU Tools](https://gitlab.freedesktop.org/drm/igt-gpu-tools)
* [Howdy Project](https://github.com/boltgolt/howdy)
* [Podman Documentation](https://docs.podman.io/)

---

## ✍️ Author
**Juan Carlos Ramos Moll (CarlesRa)**

---

⭐ If this repository helped you, consider starring it and contributing improvements.