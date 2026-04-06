from __future__ import annotations

import io
import mimetypes
import os
import posixpath
import urllib.parse
import uuid
from dataclasses import dataclass
from datetime import timedelta
from pathlib import Path
from typing import BinaryIO

from minio import Minio


LOCAL_SCHEME = "local"
MINIO_SCHEME = "minio"


@dataclass(frozen=True)
class ObjectRef:
    scheme: str
    bucket: str
    key: str

    @property
    def value(self) -> str:
        return f"{self.scheme}://{self.bucket}/{self.key}"


class ObjectStorageService:
    def __init__(self) -> None:
        self.internal_endpoint = os.getenv("MUSELENS_MINIO_ENDPOINT", "").strip()
        self.public_endpoint = os.getenv("MUSELENS_MINIO_PUBLIC_ENDPOINT", "").strip()
        self.access_key = os.getenv("MUSELENS_MINIO_ACCESS_KEY", "").strip()
        self.secret_key = os.getenv("MUSELENS_MINIO_SECRET_KEY", "").strip()
        self.secure = self._to_bool(os.getenv("MUSELENS_MINIO_SECURE"), False)
        self.public_secure = self._to_bool(
            os.getenv("MUSELENS_MINIO_PUBLIC_SECURE"),
            self.secure,
        )
        self.local_root = Path(
            os.getenv("MUSELENS_LOCAL_ASSET_DIR", os.path.join(os.getcwd(), ".local-assets"))
        )
        self.public_api_base_url = os.getenv("PUBLIC_API_BASE_URL", "").rstrip("/")
        self.signed_url_expire_seconds = int(os.getenv("SIGNED_URL_EXPIRE_SECONDS", "3600"))
        self.input_bucket = os.getenv("MUSELENS_MINIO_BUCKET_INPUT", "muselens-input").strip()
        self.output_bucket = os.getenv("MUSELENS_MINIO_BUCKET_OUTPUT", "muselens-output").strip()
        self.temp_bucket = os.getenv("MUSELENS_MINIO_BUCKET_TEMP", "muselens-temp").strip()

        self._client = self._build_client(self.internal_endpoint, self.secure)
        self._public_client = self._build_client(
            self.public_endpoint or self.internal_endpoint,
            self.public_secure,
        )

    @staticmethod
    def _to_bool(value: str | None, default: bool) -> bool:
        if value is None or value == "":
            return default
        return value.strip().lower() in {"1", "true", "yes", "on"}

    def _build_client(self, endpoint: str, secure: bool) -> Minio | None:
        if not endpoint or not self.access_key or not self.secret_key:
            return None
        return Minio(
            endpoint,
            access_key=self.access_key,
            secret_key=self.secret_key,
            secure=secure,
        )

    @property
    def is_minio_enabled(self) -> bool:
        return self._client is not None

    def _ensure_bucket(self, bucket: str) -> None:
        if not self._client:
            return
        if not self._client.bucket_exists(bucket):
            self._client.make_bucket(bucket)

    def normalize_key(self, *parts: str) -> str:
        cleaned = [segment.strip().strip("/") for segment in parts if segment and segment.strip("/")]
        return posixpath.join(*cleaned) if cleaned else uuid.uuid4().hex

    def build_object_ref(self, bucket: str, key: str, scheme: str | None = None) -> str:
        return ObjectRef(scheme=scheme or (MINIO_SCHEME if self.is_minio_enabled else LOCAL_SCHEME), bucket=bucket, key=key).value

    def parse_object_ref(self, value: str) -> ObjectRef:
        if not value:
            raise ValueError("Object ref is empty.")
        if value.startswith("http://") or value.startswith("https://"):
            raise ValueError("HTTP URL is not an object ref.")
        parsed = urllib.parse.urlparse(value)
        if parsed.scheme in {MINIO_SCHEME, LOCAL_SCHEME}:
            bucket = parsed.netloc
            key = parsed.path.lstrip("/")
            if not bucket or not key:
                raise ValueError(f"Invalid object ref: {value}")
            return ObjectRef(parsed.scheme, bucket, key)
        if "/" not in value:
            raise ValueError(f"Unsupported object ref: {value}")
        bucket, key = value.split("/", 1)
        scheme = MINIO_SCHEME if self.is_minio_enabled else LOCAL_SCHEME
        return ObjectRef(scheme, bucket, key)

    def put_bytes(
        self,
        *,
        bucket: str,
        key: str,
        data: bytes,
        content_type: str = "application/octet-stream",
    ) -> str:
        if self.is_minio_enabled:
            self._ensure_bucket(bucket)
            assert self._client is not None
            self._client.put_object(
                bucket,
                key,
                io.BytesIO(data),
                len(data),
                content_type=content_type,
            )
            return self.build_object_ref(bucket, key, MINIO_SCHEME)

        target = self.local_root / bucket / key
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        return self.build_object_ref(bucket, key, LOCAL_SCHEME)

    def put_fileobj(
        self,
        *,
        bucket: str,
        key: str,
        fileobj: BinaryIO,
        content_type: str = "application/octet-stream",
    ) -> str:
        data = fileobj.read()
        return self.put_bytes(bucket=bucket, key=key, data=data, content_type=content_type)

    def get_bytes(self, object_ref: str) -> bytes:
        parsed = self.parse_object_ref(object_ref)
        if parsed.scheme == MINIO_SCHEME:
            assert self._client is not None
            response = self._client.get_object(parsed.bucket, parsed.key)
            try:
                return response.read()
            finally:
                response.close()
                response.release_conn()

        target = self.local_root / parsed.bucket / parsed.key
        return target.read_bytes()

    def stat(self, object_ref: str) -> dict:
        parsed = self.parse_object_ref(object_ref)
        if parsed.scheme == MINIO_SCHEME:
            assert self._client is not None
            stat = self._client.stat_object(parsed.bucket, parsed.key)
            return {
                "content_type": stat.content_type or mimetypes.guess_type(parsed.key)[0] or "application/octet-stream",
                "size": stat.size,
            }

        target = self.local_root / parsed.bucket / parsed.key
        return {
            "content_type": mimetypes.guess_type(str(target))[0] or "application/octet-stream",
            "size": target.stat().st_size,
        }

    def build_proxy_url(self, object_ref: str) -> str:
        encoded = urllib.parse.quote(object_ref, safe="")
        return f"{self.public_api_base_url}/api/v1/storage/object?ref={encoded}" if self.public_api_base_url else f"/api/v1/storage/object?ref={encoded}"

    def get_download_url(self, object_ref: str) -> str:
        if object_ref.startswith(("http://", "https://")):
            return object_ref
        parsed = self.parse_object_ref(object_ref)
        if parsed.scheme == MINIO_SCHEME and self._public_client is not None and self.public_endpoint:
            return self._public_client.presigned_get_object(
                parsed.bucket,
                parsed.key,
                expires=timedelta(seconds=self.signed_url_expire_seconds),
            )
        return self.build_proxy_url(object_ref)

    def build_input_object_key(self, *, session_id: str, filename: str) -> str:
        return self.normalize_key("input", session_id, f"{uuid.uuid4().hex}_{filename}")

    def build_intermediate_object_key(self, *, session_id: str, step_id: str, filename: str) -> str:
        return self.normalize_key("intermediate", session_id, step_id, f"{uuid.uuid4().hex}_{filename}")

    def build_output_object_key(self, *, session_id: str, step_id: str, filename: str) -> str:
        return self.normalize_key("output", session_id, step_id, f"{uuid.uuid4().hex}_{filename}")


storage_service = ObjectStorageService()
