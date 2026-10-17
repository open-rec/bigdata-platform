"""Readiness and an actual embedding smoke check; only Python stdlib is required."""
import json
import math
import os
import sys
import urllib.request

base = "http://127.0.0.1:8000"
headers = {"Content-Type": "application/json"}
if os.getenv("VLLM_API_KEY"):
    headers["Authorization"] = "Bearer " + os.environ["VLLM_API_KEY"]
if len(sys.argv) > 1 and sys.argv[1] == "health":
    with urllib.request.urlopen(base + "/health", timeout=4) as response:
        assert response.status == 200
else:
    payload = {"model": os.getenv("VLLM_MODEL_NAME", "Qwen/Qwen3-Embedding-0.6B"),
               "input": ["OpenRec embedding smoke"], "encoding_format": "float"}
    request = urllib.request.Request(base + "/v1/embeddings", headers=headers,
                                     data=json.dumps(payload).encode())
    with urllib.request.urlopen(request, timeout=30) as response:
        vector = json.load(response)["data"][0]["embedding"]
    expected = int(os.getenv("VLLM_EMBEDDING_DIMENSIONS", "1024"))
    assert len(vector) == expected and all(math.isfinite(x) for x in vector)
    assert sum(x*x for x in vector) > 0
    print("embedding smoke passed: %s dimensions" % len(vector))
