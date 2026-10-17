#!/usr/bin/env bash
set -euo pipefail
model_name="${VLLM_MODEL_NAME:-Qwen/Qwen3-Embedding-0.6B}"
model_path="${VLLM_MODEL_PATH:-${VLLM_MODEL_ROOT:-/models}/${model_name}}"
[[ -f "${model_path}/config.json" ]] || {
  echo "Model not found at ${model_path}; mount the model directory and configure VLLM_MODEL_PATH or VLLM_MODEL_NAME" >&2
  exit 1
}
args=(serve "${model_path}" --host 0.0.0.0 --port 8000
  --served-model-name "${model_name}" --runner pooling
  --dtype "${VLLM_DTYPE:-half}"
  --max-model-len "${VLLM_MAX_MODEL_LEN:-512}"
  --gpu-memory-utilization "${VLLM_GPU_MEMORY_UTILIZATION:-0.2}"
  --max-num-seqs "${VLLM_MAX_NUM_SEQS:-32}"
  --tensor-parallel-size "${VLLM_TENSOR_PARALLEL_SIZE:-1}")
# Leave pooling to the model by default; override only with an explicitly compatible recipe.
if [[ -n "${VLLM_POOLER_CONFIG:-}" ]]; then
  args+=(--pooler-config "${VLLM_POOLER_CONFIG}")
fi
if [[ -n "${VLLM_API_KEY:-}" ]]; then args+=(--api-key "${VLLM_API_KEY}"); fi
exec vllm "${args[@]}" "$@"
