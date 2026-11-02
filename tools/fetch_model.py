"""Downloads the speech model folder and its tokenizer files into Models/ (about 0.5 GB, once).
Sources: huggingface.co/argmaxinc/whisperkit-coreml (model, MIT) and huggingface.co/openai/whisper-small (tokenizer, Apache-2.0).

Safety checks: HTTPS to huggingface.co only, every target path must stay inside Models/,
every download goes to a temporary file first, and large files are checked against the
SHA-256 hash that the model host publishes for them."""
import hashlib
import json
import pathlib
import urllib.request

NAME = "openai_whisper-small"
HOST = "https://huggingface.co/"
ROOT = pathlib.Path("Models").resolve()
TIMEOUT = 60


def safe_target(relative):
    target = (ROOT / relative).resolve()
    if ROOT not in target.parents:
        raise SystemExit(f"refusing a path outside Models/: {relative}")
    return target


def sha256_of(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def fetch(url, target, expected_sha=None, expected_size=None):
    if not url.startswith(HOST):
        raise SystemExit(f"refusing a download from outside {HOST}: {url}")
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(target.name + ".part")
    with urllib.request.urlopen(url, timeout=TIMEOUT) as response, open(temporary, "wb") as out:
        while block := response.read(1 << 20):
            out.write(block)
    if expected_size is not None and temporary.stat().st_size != expected_size:
        temporary.unlink()
        raise SystemExit(f"size mismatch for {target.name}")
    if expected_sha is not None and sha256_of(temporary) != expected_sha:
        temporary.unlink()
        raise SystemExit(f"hash mismatch for {target.name}")
    temporary.replace(target)


def already_good(target, size, sha):
    return target.exists() and target.stat().st_size == size and (sha is None or sha256_of(target) == sha)


listing = json.load(urllib.request.urlopen(
    f"{HOST}api/models/argmaxinc/whisperkit-coreml/tree/main/{NAME}?recursive=true", timeout=TIMEOUT))
for item in listing:
    if item["type"] != "file":
        continue
    target = safe_target(item["path"])
    sha = (item.get("lfs") or {}).get("oid")
    if not already_good(target, item["size"], sha):
        fetch(f"{HOST}argmaxinc/whisperkit-coreml/resolve/main/{item['path']}", target, sha, item["size"])
        print("fetched", item["path"])
for name in ("tokenizer.json", "tokenizer_config.json"):
    fetch(f"{HOST}openai/whisper-small/resolve/main/{name}", safe_target(f"{NAME}/{name}"))
print("done")
