# syntax=docker/dockerfile:1
# 需要 Docker BuildKit（Docker Desktop 默认开启）：缓存加速重复构建
#   docker compose build
# 若需官方 PyPI：docker compose build --build-arg PIP_INDEX_URL=https://pypi.org/simple

FROM python:3.12-slim-bookworm

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# 国内 PyPI（构建时可 --build-arg 覆盖为 https://pypi.org/simple）
ARG PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

# apt 使用清华 Debian 镜像 + apt 缓存挂载（加速重复 docker build）
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    if [ -f /etc/apt/sources.list.d/debian.sources ]; then \
      sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g; s|security.debian.org|mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/debian.sources; \
    fi; \
    if [ -f /etc/apt/sources.list ]; then \
      sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g; s|security.debian.org|mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list; \
    fi; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates; \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt requirements-dev.txt /app/

# pip 缓存挂载：重复构建时复用已下载 wheel，显著缩短时间
# 去掉 --no-cache-dir，否则无法利用挂载缓存
RUN --mount=type=cache,target=/root/.cache/pip \
    python -m pip install --upgrade pip -i "${PIP_INDEX_URL}" \
    && python -m pip install \
        -i "${PIP_INDEX_URL}" \
        -r /app/requirements.txt \
        -r /app/requirements-dev.txt

COPY . /app

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
