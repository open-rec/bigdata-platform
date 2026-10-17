# OpenRec's optional embedding runtime. Model weights are mounted, never baked in.
# v0.31.0 uses CUDA 12.9 and supports Qwen3 embedding on CUDA 12.9-capable drivers.
ARG VLLM_BASE_IMAGE=vllm/vllm-openai:v0.31.0-cu129
FROM ${VLLM_BASE_IMAGE}
# Upstream cu129 bundles a CUDA 13 TorchCodec wheel (vllm issue #60406).
# Pin the latest published cu129 TorchCodec wheel; preserve PyTorch via --no-deps.
RUN python3 -m pip install --no-cache-dir --no-deps --force-reinstall \
    torchcodec==0.16.0+cu129 --index-url https://download.pytorch.org/whl/cu129 \
    && python3 -c "import torchcodec.decoders; import vllm.engine.arg_utils"
COPY entrypoint.sh /usr/local/bin/openrec-vllm
COPY probe.py /opt/openrec/probe.py
RUN chmod +x /usr/local/bin/openrec-vllm
ENV VLLM_MODEL_NAME=Qwen/Qwen3-Embedding-0.6B \
    VLLM_MODEL_ROOT=/models \
    HF_HUB_OFFLINE=1 \
    VLLM_NO_USAGE_STATS=1 \
    DO_NOT_TRACK=1
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=5s --start-period=180s --retries=10 \
    CMD python3 /opt/openrec/probe.py health
ENTRYPOINT ["/usr/local/bin/openrec-vllm"]
