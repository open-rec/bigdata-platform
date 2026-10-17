# vLLM embedding infrastructure

`openrec/vllm:0.31.0` wraps the official `vllm/vllm-openai:v0.31.0-cu129` CUDA 12.9 image.
It provides the OpenAI-compatible `POST /v1/embeddings` API. Qwen3-Embedding-0.6B
is the default model; weights are read from a user-configured, read-only mount.
No weights or host-specific model paths are baked into the image.
The upstream CUDA 12.9 image bundles a CUDA 13 TorchCodec wheel
([upstream issue #60406](https://github.com/vllm-project/vllm/issues/60406)).
This image pins the latest published CUDA 12.9 TorchCodec wheel, `0.16.0+cu129`,
using `--no-deps`, retaining CUDA PyTorch, GPU model inference, and CUDA media
decoding support. The build checks TorchCodec and vLLM engine imports; runtime
smoke checks validate GPU inference.

The component is optional: neither `standalone`, `cluster`, nor the compatibility
alias `all` starts it automatically. NVIDIA Container Toolkit and a driver compatible
with the image's CUDA runtime are required. Compose selects one GPU; use a Compose
override for multiple device IDs when configuring tensor parallelism.

```bash
export VLLM_MODEL_DIR=/path/to/modelscope/models
export VLLM_MODEL_NAME=Qwen/Qwen3-Embedding-0.6B
export VLLM_GPU_DEVICE=0
./platform.sh build vllm
./platform.sh up vllm
./platform.sh smoke vllm
```

The root directory must contain `Qwen/Qwen3-Embedding-0.6B/config.json` and the other
model files. To mount a different layout, configure `VLLM_MODEL_PATH` with its
**container** path beneath `/models`. `--served-model-name` keeps the HTTP model ID
independent of filesystem paths. Missing model files cause startup to fail without
attempting a remote model download. Additional `docker run` arguments are passed
to `vllm serve` as separate arguments.

`env.example` lists deployment settings. Image tag and base image are configurable
through `VLLM_VERSION` and `VLLM_BASE_IMAGE`; the startup flags are tested with 0.31.0.
This version uses `--runner pooling` and `--pooler-config`. The `-cu129` base
image targets CUDA 12.9; the upstream tag without that suffix uses CUDA 13.0.
The default model length is 512 tokens, matching the offline encoder. Overlong HTTP
inputs are rejected by the backend; they are not silently encoded with a different
truncation recipe. Set `VLLM_POOLER_CONFIG` only when intentionally changing the
model's pooling configuration, then revalidate/regenerate candidate vectors.

The host port defaults to `127.0.0.1:8000`; containers use `http://vllm:8000` on
`openrec-bigdata`. `VLLM_API_KEY` optionally protects inference requests. Health
checks use `/health`; `platform.sh smoke vllm` performs real inference and validates
finite, nonzero vectors with `VLLM_EMBEDDING_DIMENSIONS` dimensions.

## OpenRec integration

Export matching settings before running either example startup script:

```bash
export EMBEDDING_ENABLED=true
export EMBEDDING_MODEL=Qwen/Qwen3-Embedding-0.6B
export EMBEDDING_ENDPOINT=http://vllm:8000/v1/embeddings
# When enabled, configure EMBEDDING_API_KEY to match VLLM_API_KEY.
```

The example builds/starts vLLM, waits for a real embedding response, compares samples
against `model/recall/item/item_title_emb.csv`, then initializes the global
`query-title-emb-index` alias. `VLLM_PORT` controls the host-side verification
URL; `EMBEDDING_VERIFY_ENDPOINT` can explicitly override it.

The query recipe belongs to the caller: Qwen requests use
`Instruct: <instruction>\nQuery:<query>`, while document/title requests contain plain
text. `OPENREC_TEXT_EMBEDDING_INSTRUCTION` configures the same instruction in
rec-server and the offline Python encoder. Model/revision, last-token pooling,
normalization, dimensions, tokenization, and text preparation must agree. Replacing
the model requires regenerating and validating candidate vectors, not just changing
an environment variable. Each vLLM instance serves its configured model; additional
models should use separate service instances.

References: [vLLM pooling models](https://docs.vllm.ai/en/v0.31.0/models/pooling_models/),
[Qwen model](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B).
