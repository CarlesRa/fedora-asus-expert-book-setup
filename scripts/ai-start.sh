#!/bin/bash
# ai-start — Smart AI stack (Improved Detection)
# Optimized for Intel Core Ultra 7 255H

PORT="${1:-8081}"
OLLAMA_URL="http://127.0.0.1:11434"

echo "🔍 Scanning 'dev-ai' container for tools..."

# --- English Comments: Robust Tool Detection ---
# We try to run the version command. If it returns 0, the tool exists.
HAS_LLAMA=false
if distrobox enter dev-ai -- llama-server --version >/dev/null 2>&1; then
    HAS_LLAMA=true
fi

HAS_OLLAMA_BIN=false
if distrobox enter dev-ai -- ollama --version >/dev/null 2>&1; then
    HAS_OLLAMA_BIN=true
fi

# Check if Ollama server is actually answering
OLLAMA_RUNNING=false
if [ "$HAS_OLLAMA_BIN" = true ] && curl -s --connect-timeout 2 "$OLLAMA_URL/api/tags" > /dev/null; then
    OLLAMA_RUNNING=true
fi

# Exit if everything fails
if [ "$HAS_LLAMA" = false ] && [ "$HAS_OLLAMA_BIN" = false ]; then
    echo "❌ Error: Neither llama-server nor ollama were found or are executable in 'dev-ai'."
    echo "   Check if they are installed inside the container."
    exit 1
fi

# --- English Comments: Engine Selection Menu ---
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

# --- English Comments: Model Selection ---
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

# --- English Comments: Execution Logic ---
if [[ "$SELECTED_ENGINE" == *"Ollama"* ]]; then
    # MODE: OLLAMA
    MODEL_NAME=$(echo "$MODEL_FILENAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
    echo "🔄 Syncing GGUF with Ollama: $MODEL_NAME..."
    distrobox enter dev-ai -- sh -c "echo 'FROM $MODEL_PATH' | ollama create $MODEL_NAME -f -" > /dev/null
    
    echo "🚀 Launching Open WebUI via Ollama..."
    export OLLAMA_BASE_URL="$OLLAMA_URL"
    distrobox enter dev-ai -- open-webui serve

else
    # MODE: LLAMA.CPP (llama-server)
    echo "🚀 Launching llama-server (CPU Only / 8 Threads)..."
    
    # Starting llama-server in background
    distrobox enter dev-ai -- llama-server \
        -m "$MODEL_PATH" \
        --alias "active-model" \
        --port "$PORT" \
        -ngl 0 \
        -t 8 \
        -c 2048 > /tmp/llama.log 2>&1 &
    
    LLAMA_PID=$!
    sleep 2
    echo "🖥️  Starting Open WebUI... (Use 'active-model' in the UI)"
    
    # Ensure background process dies on Ctrl+C
    trap "echo ''; echo 'Stopping...'; kill $LLAMA_PID 2>/dev/null; exit 0" INT
    distrobox enter dev-ai -- open-webui serve
fi