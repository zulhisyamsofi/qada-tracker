"""Transfer checked APKs into private GitHub drafts using the runner's token.

No signing key or personal access token is stored. Refresh the temporary URLs
in release-assets.json before rerunning after their 72-hour lifetime.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import urllib.parse
import urllib.request


def api(path):
    return json.loads(subprocess.check_output(["gh", "api", path], text=True))


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    repo = os.environ["GH_REPO"]
    if repo != "zulhisyamsofi/qada-tracker":
        raise ValueError("This publisher is scoped to the Qada Tracker repository.")
    entries = json.loads(Path(".github/release-assets.json").read_text())
    if {e["tag"] for e in entries} != {f"v1.{n}.0" for n in range(6)} or len(entries) != 6:
        raise ValueError("Expected exactly the six checked feature editions.")
    with tempfile.TemporaryDirectory(prefix="qada-release-") as temporary:
        for entry in entries:
            tag = entry["tag"]
            parsed = urllib.parse.urlsplit(entry["url"])
            if parsed.scheme != "https" or parsed.netloc != "litter.catbox.moe":
                raise ValueError("Transfer URLs must use the approved HTTPS file host.")
            if not re.fullmatch(r"[0-9a-f]{64}", entry["sha256"]):
                raise ValueError("Invalid expected SHA-256.")
            ref = api(f"repos/{repo}/git/ref/tags/{tag}")["object"]
            if ref["type"] != "tag":
                raise ValueError(f"{tag} must remain an annotated tag.")
            target = api(f"repos/{repo}/git/tags/{ref['sha']}")["object"]
            if target["type"] != "commit" or target["sha"] != entry["commit"]:
                raise ValueError(f"The source commit for {tag} changed.")
            release = api(f"repos/{repo}/releases/tags/{tag}")
            if not release["draft"]:
                raise ValueError(f"Refusing to replace assets on published release {tag}.")
            folder = Path(temporary, tag)
            folder.mkdir()
            apk = folder / f"qada-tracker-{tag}.apk"
            # Deliberately send no GitHub authorization header to the file host.
            with urllib.request.urlopen(entry["url"], timeout=120) as response, apk.open("wb") as stream:
                while block := response.read(1024 * 1024):
                    stream.write(block)
                    if stream.tell() > entry["size"]:
                        raise ValueError(f"{tag} exceeds its verified size.")
            if apk.stat().st_size != entry["size"] or sha256(apk) != entry["sha256"]:
                raise ValueError(f"Checksum/size mismatch for {tag}.")
            checksum = folder / "SHA256SUMS"
            checksum.write_text(f"{entry['sha256']}  {apk.name}\n")
            subprocess.run(["gh", "release", "upload", tag, str(apk), str(checksum), "--repo", repo, "--clobber"], check=True)
            assets = {a["name"]: a for a in api(f"repos/{repo}/releases/tags/{tag}")["assets"]}
            for file in [apk, checksum]:
                asset = assets[file.name]
                if asset["size"] != file.stat().st_size:
                    raise ValueError(f"Uploaded size mismatch for {file.name}.")
                digest = asset.get("digest")
                if digest is not None:
                    if digest != "sha256:" + sha256(file):
                        raise ValueError(f"Uploaded digest mismatch for {file.name}.")
                else:
                    verify = folder / "download-check"
                    verify.mkdir(exist_ok=True)
                    subprocess.run(["gh", "release", "download", tag, "--repo", repo, "--pattern", file.name, "--dir", str(verify)], check=True)
                    if sha256(verify / file.name) != sha256(file):
                        raise ValueError(f"Downloaded digest mismatch for {file.name}.")
            print(f"Verified private draft assets for {tag}", flush=True)
            summary = os.environ.get("GITHUB_STEP_SUMMARY")
            if summary:
                with open(summary, "a") as stream:
                    stream.write(f"- {tag}: APK and SHA256SUMS uploaded and verified.\n")


if __name__ == "__main__":
    main()
