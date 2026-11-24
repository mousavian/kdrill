# syntax=docker/dockerfile:1.7
# kdrill.local/ml-dev: Python + numpy + CPU-only PyTorch + pytest, for local
# courses that run the learner's own ML code (llm-from-zero). Built for the host
# architecture with plain `docker build` by build.sh; never pushed, never imported
# into a cluster.
FROM python:3.13-slim@sha256:e48f59cdba69a3cbd9ed2cf0f348d90d45a8d350d98134cf1070bc106ee9ed90

# PyTorch's CPU index has linux/amd64 and linux/arm64 wheels (the plain PyPI
# Linux wheels pull in several GB of CUDA libraries).
ARG TORCH_VERSION=2.15.0+cpu
ARG TORCH_INDEX=https://download.pytorch.org/whl/cpu
# An optional extra CA bundle (build secret "ca") for builds behind a TLS-inspecting proxy.
RUN --mount=type=secret,id=ca,required=false \
    if [ -s /run/secrets/ca ]; then export PIP_CERT=/run/secrets/ca; fi; \
    pip install --no-cache-dir --index-url "$TORCH_INDEX" "torch==${TORCH_VERSION}" \
 && pip install --no-cache-dir numpy==2.4.6 pytest==9.2.0 tqdm==4.70.1 matplotlib==3.11.2 \
 && find /usr/local/lib/python3.13 -name __pycache__ -prune -exec rm -rf {} + \
 && cd /usr/local/lib/python3.13/site-packages/torch \
 && rm -rf include share/cmake test \
 && find bin -type f ! -name torch_shm_manager -delete

# kdrill's pytest reporter: one line per behaviour, names the failing behaviour,
# hides tracebacks, enforces a per-test timeout.
COPY kdreport.py /opt/kdrill/kdreport.py

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    MPLBACKEND=Agg \
    PYTHONPATH=/opt/kdrill
WORKDIR /work
CMD ["python3"]
