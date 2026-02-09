# MediaAI Tools - Dockerfile
# Multi-stage build for optimized image size

# Stage 1: Base image with CUDA support
FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04 AS base

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    python3.10-venv \
    ffmpeg \
    git \
    wget \
    curl \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# 创建工作目录
WORKDIR /app

# Stage 2: Python dependencies
FROM base AS builder

# 复制 requirements 文件
COPY src/requirements.txt /app/src/requirements.txt
COPY api/requirements.txt /app/api/requirements.txt

# 安装 Python 依赖
RUN pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir -r /app/src/requirements.txt && \
    pip3 install --no-cache-dir -r /app/api/requirements.txt

# 安装 PyTorch with CUDA support
RUN pip3 install --no-cache-dir \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu121

# Stage 3: Final runtime image
FROM base AS runtime

# 从 builder 复制已安装的 Python 包
COPY --from=builder /usr/local/lib/python3.10/dist-packages /usr/local/lib/python3.10/dist-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# 复制项目文件
COPY src/ /app/src/
COPY api/ /app/api/
COPY web/ /app/web/
#COPY .github/copilot-instructions.md /app/.github/copilot-instructions.md

# 创建必要的目录
RUN mkdir -p /app/uploads /app/output /app/logs /app/models

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/api/info || exit 1
# RUN python3 -c "from transformers import Qwen2VLForConditionalGeneration; Qwen2VLForConditionalGeneration.from_pretrained('Qwen/Qwen2-VL-2B-Instruct')"

# 暴露端口
EXPOSE 8000

# 启动命令
CMD ["python3", "-m", "uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]