#!/bin/bash
# ai-start — Smart AI stack launcher
# Optimized for Intel Core Ultra 7 255H
# Uses separate Distrobox containers: 'llama-cpp' and 'ollama'

PORT="${1:-8081}"
OLLAMA_URL="http://127.0.0.1:11434"

echo "🔍 Detecting available tools..."

# Check llama-server inside the 'llama-cpp' container
HAS_LLAMA=false
if distrobox enter llama-cpp -- llama-server --version >/dev/null 2>&1; then
    HAS_LLAMA=true
fi

# Check ollama inside the 'ollama' container
HAS_OLLAMA_BIN=false
if distrobox enter ollama -- ollama --version >/dev/null 2>&1; then
    HAS_OLLAMA_BIN=true
fi

# Check if Ollama server is actually answering
OLLAMA_RUNNING=false
if [ "$HAS_OLLAMA_BIN" = true ] && curl -s --connect-timeout 2 "$OLLAMA_URL/api/tags" > /dev/null; then
    OLLAMA_RUNNING=true
fi

# Exit if everything fails
if [ "$HAS_LLAMA" = false ] && [ "$HAS_OLLAMA_BIN" = false ]; then
    echo "❌ Error: Neither llama-server (in 'llama-cpp') nor ollama (in 'ollama') were found."
    echo "   Check that the containers exist and tools are installed."
    exit 1
fi

# --- Engine Selection Menu ---
echo ""
echo "🤖 Select AI Engine:"
options=()
[[ "$HAS_LLAMA" == "true" ]] && options+=("llama.cpp (Direct Server)")
[[ "$OLLAMA_RUNNING" == "true" ]] && options+=("Ollama (Service Active)")
options+=("Cancel")

for i in "${!options[@]}"; do
    echo "$((i+1))) ${options[$i]}"
done

read -p "Selection: " engine_choice
SELECTED_ENGINE="${options[$((engine_choice-1))]}"

if [[ "$SELECTED_ENGINE" == "Cancel" || -z "$SELECTED_ENGINE" ]]; then
    exit 0
fi

# --- Model Selection ---
echo ""
echo "📦 Available models in ~/Models:"
models=(~/Models/*.gguf)
for i in "${!models[@]}"; do
    echo "$((i+1))) $(basename "${models[$i]}")"
done
echo "$((${#models[@]}+1))) Cancel"
echo ""
read -p "Select a model: " model_choice

if [[ "$model_choice" -eq "$((${#models[@]}+1))" || -z "$model_choice" ]]; then
    exit 0
fi

MODEL_PATH="${models[$((model_choice-1))]}"
MODEL_FILENAME=$(basename "$MODEL_PATH")

# --- Execution Logic ---
if [[ "$SELECTED_ENGINE" == *"Ollama"* ]]; then
    # MODE: OLLAMA — runs inside 'ollama' container
    MODEL_NAME=$(echo "$MODEL_FILENAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
    echo "🔄 Syncing GGUF with Ollama: $MODEL_NAME..."
    distrobox enter ollama -- sh -c "echo 'FROM $MODEL_PATH' | ollama create $MODEL_NAME -f -" > /dev/null

    echo "🚀 Launching Open WebUI via Ollama..."
    export OLLAMA_BASE_URL="$OLLAMA_URL"
    distrobox enter ollama -- open-webui serve

else
    # MODE: LLAMA.CPP — runs inside 'llama-cpp' container
    echo "🚀 Launching llama-server (CPU Only / 8 Threads)..."

    # Start llama-server in background inside 'llama-cpp' container
    distrobox enter llama-cpp -- llama-server \
        -m "$MODEL_PATH" \
        --alias "active-model" \
        --port "$PORT" \
        -ngl 0 \
        -t 8 \
        -c 2048 > /tmp/llama.log 2>&1 &

    LLAMA_PID=$!
    sleep 2
    echo "   PID: $LLAMA_PID — logs at /tmp/llama.log"
    echo "🖥️  Open WebUI connects to llama-server at http://localhost:$PORT/v1"
    echo "   In Open WebUI → Admin Panel → Settings → Connections:"
    echo "   URL: http://localhost:$PORT/v1  |  API Key: llama"
    echo ""
    echo "   Press Ctrl+C to stop llama-server"

    # Ensure background process dies on Ctrl+C
    trap "echo ''; echo 'Stopping...'; kill $LLAMA_PID 2>/dev/null; exit 0" INT
    wait $LLAMA_PID
fi
