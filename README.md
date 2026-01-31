Perfect. Here is the updated README.md in English, incorporating all the optimizations we’ve implemented for your ASUS ExpertBook, including the GPU acceleration, Distrobox workflow, and battery health management.
Linux Asus ExpertBook Setup

Target device: Asus ExpertBook (Intel Core Ultra)

This repository documents an evolving set of Linux laptop configurations and experiments, currently tested on an Asus ExpertBook running Fedora 43. The setup focuses on balancing high performance, hardware longevity, and a clean development workflow.
💻 Hardware Specifications

    Device: Asus ExpertBook B5405CCA

    CPU: Intel Core Ultra 7 (Arrow Lake-P)

    GPU: Intel Graphics (Integrated Arrow Lake-P GPU @ 2.25 GHz)

    NPU: Intel AI Boost (Neural Processing Unit)

    RAM: 32 GB

    Storage: 1 TB NVMe SSD (btrfs)

    Operating System: Fedora 43 (Workstation Edition)

    Desktop Environment: GNOME 49 (Wayland)

⚡ 1. GPU & Multimedia Optimization

To leverage the Arrow Lake architecture for hardware-accelerated video decoding (YouTube, streaming, etc.), reducing CPU load and heat.
1.1 Enable RPM Fusion Repositories

Fedora requires these for non-free codecs and drivers.
Bash

sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

1.2 Video Acceleration Drivers (VA-API)

Install the modern Intel Media Driver for hardware decoding/encoding (H.264, HEVC, VP9, and AV1).
Bash

sudo dnf install intel-media-driver libva-utils

Verification: Run vainfo. You should see several VAEntrypointVLD entries, including VAProfileAV1Profile0.
📦 2. Development Workflow (Distrobox)

Instead of polluting the host system with multiple language runtimes, we use Distrobox to create isolated environments that share the $HOME directory.
2.1 Installation
Bash

sudo dnf install distrobox

2.2 Example: Angular Development Box
Bash

# Create a Fedora 43 container
distrobox create --name dev-angular --image fedora:43

# Enter the box and install tools
distrobox enter dev-angular
sudo dnf install nodejs npm git -y
sudo npm install -g @angular/cli

2.3 VS Code Integration

    Install VS Code (RPM) on the host.

    Open your project folder normally.

    Use the integrated terminal and type distrobox enter dev-angular.

    Benefit: Host UI speed + Isolated container binaries.

🔋 3. Power & Battery Management (asusctl)

Essential for Asus-specific hardware features.
3.1 Installation
Bash

sudo dnf copr enable lukenukem/asus-linux
sudo dnf install asusctl
sudo systemctl enable --now asusd.service

3.2 Battery Charge Limiting

Protect your battery lifespan by limiting the maximum charge (ideal for workstations always plugged in).
Bash

# Limit charge to 60%
asusctl -c 60

3.3 Performance Profiles

    Get active profile: asusctl profile get

    Switch/Cycle profiles: asusctl profile -n (Performance, Balanced, Quiet)

🔐 4. Biometrics & Authentication

    Fingerprint Sensor: Native support in Fedora 43 via Settings > Users.

    FaceID (Howdy): Enable IR camera authentication (Optional).
    Bash

    sudo dnf copr enable principalis/howdy
    sudo dnf install howdy

🧠 5. Local AI with Ollama (Intel GPU)

Run local LLMs inside a Podman container using iGPU acceleration.
Bash

podman run -d \
  --name ollama \
  --device /dev/dri/renderD128:/dev/dri/renderD128 \
  -v ollama-data:/root/.ollama \
  -p 11434:11434 \
  docker.io/ollama/ollama:latest

⌨️ 6. Peripherals (Logitech MX Keys)

Manage battery levels and pairing for Logitech devices.
Bash

sudo dnf install solaar

✍️ Author

Juan Carlos Ramos Moll (CarlesRa)
Recent Changes (January 2026):

    ✅ Configured VA-API with AV1 support for Arrow Lake.

    ✅ Implemented Distrobox workflow for Angular development.

    ✅ Set battery charge threshold to 60% via asusctl.

    ✅ Verified Fedora 43 native hardware compatibility.