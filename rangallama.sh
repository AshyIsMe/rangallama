#!/usr/bin/env bash
set -xe

grep ubuntu /etc/os-release || (echo "only ubuntu derivatives supported" && exit)


# https://unsloth.ai/docs/models/gemma-4#llama.cpp-guide
PACKAGES="pciutils build-essential cmake curl libcurl4-openssl-dev libvulkan-dev glslc"
if ! dpkg -s $PACKAGES >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install $PACKAGES -y
fi

if [ ! -f llama.cpp/llama-cli ]; then
    git clone https://github.com/ggml-org/llama.cpp || (cd llama.cpp && git pull)
    cmake llama.cpp -B llama.cpp/build \
        -DBUILD_SHARED_LIBS=OFF -DGGML_VULKAN=1 #-DGGML_CUDA=ON
    cmake --build llama.cpp/build --config Release -j --clean-first --target llama-cli llama-mtmd-cli llama-server llama-gguf-split
    cp llama.cpp/build/bin/llama-* llama.cpp
fi



# run gemma-4-e2b
export LLAMA_CACHE="unsloth/gemma-4-E2B-it-GGUF"
./llama.cpp/llama-cli \
    -hf unsloth/gemma-4-E2B-it-GGUF:Q8_0 \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 64

## run gemma-4-26b-a4b
#export LLAMA_CACHE="unsloth/gemma-4-26B-A4B-it-GGUF"
#./llama.cpp/llama-cli \
    #-hf unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL \
    #--temp 1.0 \
    #--top-p 0.95 \
    #--top-k 64
