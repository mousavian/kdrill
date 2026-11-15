"""Where runs keep their files: a local directory (a PVC, an emptyDir) or an
S3 bucket (MinIO in the lab). Same small interface for both, so train.py,
sample.py and mlt.py do not care which one they talk to.

  s3://BUCKET/PREFIX   uses boto3; credentials and endpoint come from the
                       standard variables AWS_ACCESS_KEY_ID,
                       AWS_SECRET_ACCESS_KEY and AWS_ENDPOINT_URL
  anything else        a local directory (created when written to)
"""
import io
import os


class LocalStore:
    def __init__(self, path):
        self.path = path
        self.uri = path

    def _p(self, name):
        return os.path.join(self.path, name)

    def put(self, name, data):
        os.makedirs(self.path, exist_ok=True)
        tmp = self._p("." + name + ".tmp")
        with open(tmp, "wb") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, self._p(name))  # atomic: readers never see half a file

    def get(self, name):
        try:
            with open(self._p(name), "rb") as f:
                return f.read()
        except FileNotFoundError:
            return None

    def list(self, prefix=""):
        try:
            return sorted(n for n in os.listdir(self.path) if n.startswith(prefix) and not n.startswith("."))
        except FileNotFoundError:
            return []

    def delete(self, name):
        try:
            os.remove(self._p(name))
        except FileNotFoundError:
            pass

    def check(self):
        os.makedirs(self.path, exist_ok=True)
        probe = self._p(".write-probe")
        with open(probe, "w") as f:
            f.write("ok")
        os.remove(probe)


class S3Store:
    def __init__(self, uri):
        import boto3
        from botocore.config import Config

        rest = uri[len("s3://"):]
        self.bucket, _, prefix = rest.partition("/")
        self.prefix = prefix.strip("/")
        self.uri = uri
        self.s3 = boto3.client(
            "s3",
            region_name=os.environ.get("AWS_REGION", "us-east-1"),
            config=Config(s3={"addressing_style": "path"}, retries={"max_attempts": 3},
                          connect_timeout=5, read_timeout=30),
        )

    def _k(self, name):
        return f"{self.prefix}/{name}" if self.prefix else name

    def put(self, name, data):
        self.s3.put_object(Bucket=self.bucket, Key=self._k(name), Body=data)

    def get(self, name):
        try:
            buf = io.BytesIO()
            self.s3.download_fileobj(self.bucket, self._k(name), buf)
            return buf.getvalue()
        except Exception as e:  # botocore raises ClientError 404 for missing keys
            code = getattr(e, "response", {}).get("Error", {}).get("Code", "")
            if code in ("404", "NoSuchKey", "NotFound"):
                return None
            raise

    def list(self, prefix=""):
        out = []
        pfx = self._k(prefix) if prefix else (self.prefix + "/" if self.prefix else "")
        pager = self.s3.get_paginator("list_objects_v2")
        for page in pager.paginate(Bucket=self.bucket, Prefix=pfx):
            for o in page.get("Contents", []):
                out.append(o["Key"][len(self.prefix) + 1:] if self.prefix else o["Key"])
        return sorted(out)

    def delete(self, name):
        self.s3.delete_object(Bucket=self.bucket, Key=self._k(name))

    def check(self):
        self.s3.head_bucket(Bucket=self.bucket)


def open_store(uri):
    if not uri:
        return None
    if uri.startswith("s3://"):
        return S3Store(uri)
    return LocalStore(uri)
