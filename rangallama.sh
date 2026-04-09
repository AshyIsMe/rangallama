#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

grep ubuntu /etc/os-release >/dev/null || (echo "only ubuntu derivatives supported" && exit)


# https://unsloth.ai/docs/models/gemma-4#llama.cpp-guide
PACKAGES="pciutils build-essential cmake curl libcurl4-openssl-dev libvulkan-dev glslc"
if ! dpkg -s $PACKAGES >/dev/null 2>&1; then
    echo "Installing dependencies: " $PACKAGES
    sudo apt-get update && sudo apt-get install $PACKAGES -y
fi

if [ ! -f llama.cpp/llama-cli ]; then
    echo "Building llama.cpp"
    git clone https://github.com/ggml-org/llama.cpp || (cd llama.cpp && git pull)
    cmake llama.cpp -B llama.cpp/build \
        -DBUILD_SHARED_LIBS=OFF -DGGML_VULKAN=1 #-DGGML_CUDA=ON
    cmake --build llama.cpp/build --config Release -j --clean-first --target llama-cli llama-mtmd-cli llama-server llama-gguf-split
    cp llama.cpp/build/bin/llama-* llama.cpp
fi


declare -A MODELS MODEL_ARGS
MODELS[gemma-4-e2b]="unsloth/gemma-4-E2B-it-GGUF:Q8_0"
MODELS[gemma-4-e4b]="unsloth/gemma-4-E4B-it-GGUF:Q8_0"
MODELS[gemma-4-26b-a4b]="unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL"
MODELS[qwen3.5-35b-a3b]="unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL"

MODEL_ARGS[gemma-4-e2b]="--temp 1.0 --top-p 0.95 --top-k 64"
MODEL_ARGS[gemma-4-e4b]="--temp 1.0 --top-p 0.95 --top-k 64"
MODEL_ARGS[gemma-4-26b-a4b]="--temp 1.0 --top-p 0.95 --top-k 64"
MODEL_ARGS[qwen3.5-35b-a3b]="--ctx-size 16384 --temp 0.6 --top-p 0.95 --top-k 20 --min-p 0.00"

run_model() {
    local model="$1"
    local hf_ref="${MODELS[$model]}"
    if [ -z "$hf_ref" ]; then
        echo "Unknown model: $model"
        echo "Available models: ${!MODELS[*]}"
        exit 1
    fi
    export LLAMA_CACHE="${hf_ref%%:*}"
    ./llama.cpp/llama-cli \
        -hf "$hf_ref" \
        ${MODEL_ARGS[$model]}
}

case "${1:-}" in
    run)
        [ -z "${2:-}" ] && echo "Usage: $0 run <model>" && echo "Available models: ${!MODELS[*]}" && exit 1
        run_model "$2"
        ;;
    *)
        echo "Usage: $0 <command>"
        echo "Commands:"
        echo "  run <model>  Run a model (${!MODELS[*]})"
        exit 1
        ;;
esac
