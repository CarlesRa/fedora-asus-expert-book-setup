#!/bin/bash
# ai-start — Launch local AI stack (llama-server + Open WebUI)
# Usage: ./scripts/ai-start.sh [port]

PORT="${1:-8081}"

# Build model list with just filenames
echo "📦 Available models:"
models=(~/Models/*.gguf)
for i in "${!models[@]}"; do
    echo "$((i+1))) $(basename ${models[$i]})"
done
echo "$((${#models[@]}+1))) Cancel"
echo ""
read -p "Select a model: " choice

if [ "$choice" -eq "$((${#models[@]}+1))" ]; then
    exit 0
fi

MODEL_PATH="${models[$((choice-1))]}"
echo ""
echo "🚀 Starting llama-server with $(basename $MODEL_PATH) on port $PORT..."
llama-server -m "$MODEL_PATH" --port "$PORT" > /tmp/llama.log 2>&1 &
LLAMA_PID=$!
echo "   PID: $LLAMA_PID — logs at /tmp/llama.log"

echo "🖥️  Starting Open WebUI at http://localhost:8080"
echo "   Press Ctrl+C to stop everything"
echo ""

trap "echo ''; echo 'Stopping...'; kill $LLAMA_PID 2>/dev/null; exit 0" INT

distrobox enter dev-ai -- open-webui serve