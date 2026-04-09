#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

PORT=6969

grep ubuntu /etc/os-release >/dev/null || (echo "only ubuntu derivatives supported" && exit)

# unsloth is great:
# https://unsloth.ai/docs/models/gemma-4#llama.cpp-guide
# https://unsloth.ai/docs/models/qwen3.5#llama.cpp-guides

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

declare -A SERVER_REPO SERVER_GGUF SERVER_MMPROJ_NAME SERVER_ALIAS SERVER_ARGS
SERVER_REPO[qwen3.5-35b-a3b]="unsloth/Qwen3.5-35B-A3B-GGUF"
SERVER_GGUF[qwen3.5-35b-a3b]="Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf"
SERVER_MMPROJ_NAME[qwen3.5-35b-a3b]="mmproj-F16.gguf"
SERVER_ALIAS[qwen3.5-35b-a3b]="unsloth/Qwen3.5-35B-A3B"
SERVER_ARGS[qwen3.5-35b-a3b]="--temp 0.6 --top-p 0.95 --ctx-size 16384 --top-k 20 --min-p 0.00"

SERVER_REPO[gemma-4-26b-a4b]="unsloth/gemma-4-26B-A4B-it-GGUF"
SERVER_GGUF[gemma-4-26b-a4b]="gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf"
SERVER_MMPROJ_NAME[gemma-4-26b-a4b]="mmproj-BF16.gguf"
SERVER_ALIAS[gemma-4-26b-a4b]="unsloth/gemma-4-26B-A4B-it-GGUF"
SERVER_ARGS[gemma-4-26b-a4b]="--temp 1.0 --top-p 0.95 --top-k 64 --chat-template-kwargs '{\"enable_thinking\":true}'"

find_gguf() {
    local repo_dir="$1"
    local filename="$2"
    local result
    result=$(find "$repo_dir" -name "$filename" -print -quit 2>/dev/null)
    if [ -z "$result" ]; then
        echo "Could not find $filename in $repo_dir" >&2
        exit 1
    fi
    echo "$result"
}

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

serve_model() {
    local model="$1"
    local repo="${SERVER_REPO[$model]}"
    if [ -z "$repo" ]; then
        echo "Unknown model for serve: $model"
        echo "Available models: ${!SERVER_REPO[*]}"
        exit 1
    fi
    local model_path
    model_path=$(find_gguf "$repo" "${SERVER_GGUF[$model]}")
    local mmproj_path
    mmproj_path=$(find_gguf "$repo" "${SERVER_MMPROJ_NAME[$model]}")
    eval ./llama.cpp/llama-server \
        --model "\"$model_path\"" \
        --mmproj "\"$mmproj_path\"" \
        --alias "\"${SERVER_ALIAS[$model]}\"" \
        --port "$PORT" \
        "${SERVER_ARGS[$model]}"
}

case "${1:-}" in
    run)
        [ -z "${2:-}" ] && echo "Usage: $0 run <model>" && echo "Available models: ${!MODELS[*]}" && exit 1
        run_model "$2"
        ;;
    serve)
        [ -z "${2:-}" ] && echo "Usage: $0 serve <model>" && echo "Available models: ${!SERVER_REPO[*]}" && exit 1
        serve_model "$2"
        ;;
    *)
        echo "Usage: $0 <command>"
        echo "Commands:"
        echo "  run <model>    Run a model (${!MODELS[*]})"
        echo "  serve <model>  Serve a model (${!SERVER_REPO[*]})"
        echo ""
        echo "When serving run claude like so:"
        echo "  ANTHROPIC_BASE_URL=http://127.0.0.1:$PORT claude" 
        exit 1
        ;;
esac
