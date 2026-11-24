# syntax=docker/dockerfile:1.7
# kdrill.local/ml-tiny: CPU-only PyTorch + a tiny character-level GPT and its
# corpus, so lessons never download anything. Built for the host architecture
# by build.sh (arm64 on Apple Silicon, amd64 elsewhere).
FROM python:3.13-slim@sha256:e48f59cdba69a3cbd9ed2cf0f348d90d45a8d350d98134cf1070bc106ee9ed90

# PyTorch's CPU index has wheels for both linux/amd64 and linux/arm64 (2.15.0+cpu,
# about 190 MB). The plain PyPI wheels for Linux depend on the CUDA packages
# (several GB) on both architectures, so the CPU index is used for every arch.
ARG TORCH_VERSION=2.15.0+cpu
ARG TORCH_INDEX=https://download.pytorch.org/whl/cpu
# An optional extra CA bundle (build secret "ca") for builds behind a TLS-inspecting proxy.
RUN --mount=type=secret,id=ca,required=false \
    if [ -s /run/secrets/ca ]; then export PIP_CERT=/run/secrets/ca; fi; \
    pip install --no-cache-dir --index-url "$TORCH_INDEX" "torch==${TORCH_VERSION}" \
 && pip install --no-cache-dir numpy==2.4.6 boto3==1.44.3 \
 && find /usr/local/lib/python3.13 -name __pycache__ -prune -exec rm -rf {} + \
 && cd /usr/local/lib/python3.13/site-packages/torch \
 && rm -rf include share/cmake test \
 && find bin -type f ! -name torch_shm_manager -delete

# Tiny Shakespeare (1.1 MB, public domain), from Andrej Karpathy's char-rnn repository.
ADD --checksum=sha256:86c4e6aa9db7c042ec79f339dcb96d42b0075e16b8fc2e86bf0ca57e2dc565ed \
    https://raw.githubusercontent.com/karpathy/char-rnn/master/data/tinyshakespeare/input.txt \
    /opt/ml-tiny/data/tinyshakespeare.txt
RUN mkdir -p /opt/ml-tiny/datasets \
 && python3 -c "import gzip,shutil; shutil.copyfileobj(open('/opt/ml-tiny/data/tinyshakespeare.txt','rb'), gzip.GzipFile('/opt/ml-tiny/datasets/tinyshakespeare.txt.gz','wb',9,mtime=0))" \
 && chmod 0644 /opt/ml-tiny/data/tinyshakespeare.txt

COPY app/ /opt/ml-tiny/app/
RUN for t in train sample prepare mlt serve; do \
      printf '#!/bin/sh\nexec python3 /opt/ml-tiny/app/%s.py "$@"\n' "$t" > /usr/local/bin/$t; \
      chmod 0755 /usr/local/bin/$t; \
    done \
 && python3 -m compileall -q /opt/ml-tiny/app

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DATA=/opt/ml-tiny/data/tinyshakespeare.txt
WORKDIR /opt/ml-tiny/app
CMD ["train", "--help"]
