"""Transfer checked APKs into private GitHub drafts using the runner's token.

No signing key or personal access token is stored. Refresh the temporary URLs
in the dispatch manifest before rerunning after their 72-hour lifetime.
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
    entries = json.loads(os.environ.get("QADA_RELEASE_MANIFEST") or Path(".github/release-assets.json").read_text())
    if not isinstance(entries, list) or not entries:
        raise ValueError("Expected a nonempty list of checked feature editions.")
    tags = [e["tag"] for e in entries]
    if len(tags) != len(set(tags)) or any(not re.fullmatch(r"v\d+\.\d+\.\d+", tag) for tag in tags):
        raise ValueError("Expected unique semantic-version app tags.")
    with tempfile.TemporaryDirectory(prefix="qada-release-") as temporary:
        for entry in entries:
            tag = entry["tag"]
            files = entry.get("files") or [{
                "name": f"qada-tracker-{tag}.apk",
                "url": entry["url"], "sha256": entry["sha256"], "size": entry["size"],
            }]
            names = [file["name"] for file in files]
            if len(names) != len(set(names)):
                raise ValueError("Duplicate asset filenames.")
            for file in files:
                if not re.fullmatch(rf"qada-tracker-{re.escape(tag)}(?:-(?:armeabi-v7a|arm64-v8a|x86_64))?\.apk", file["name"]):
                    raise ValueError("Unexpected APK filename.")
                parsed = urllib.parse.urlsplit(file["url"])
                if parsed.scheme != "https" or parsed.netloc != "litter.catbox.moe":
                    raise ValueError("Transfer URLs must use the approved HTTPS file host.")
                if not re.fullmatch(r"[0-9a-f]{64}", file["sha256"]):
                    raise ValueError("Invalid expected SHA-256.")
                if type(file["size"]) is not int or not 0 < file["size"] < 250_000_000:
                    raise ValueError("Invalid APK size.")
            ref = api(f"repos/{repo}/git/ref/tags/{tag}")["object"]
            if ref["type"] != "tag":
                raise ValueError(f"{tag} must remain an annotated tag.")
            target = api(f"repos/{repo}/git/tags/{ref['sha']}")["object"]
            if target["type"] != "commit" or target["sha"] != entry["commit"]:
                raise ValueError(f"The source commit for {tag} changed.")
            release_path = f"repos/{repo}/releases/{entry['release_id']}"
            release = api(release_path)
            if release["tag_name"] != tag:
                raise ValueError(f"Release ID does not match {tag}.")
            if not release["draft"]:
                raise ValueError(f"Refusing to replace assets on published release {tag}.")
            folder = Path(temporary, tag)
            folder.mkdir()
            downloaded = []
            for file in files:
                apk = folder / file["name"]
                # Deliberately send no GitHub authorization header to the file host.
                with urllib.request.urlopen(file["url"], timeout=120) as response, apk.open("wb") as stream:
                    while block := response.read(1024 * 1024):
                        stream.write(block)
                        if stream.tell() > file["size"]:
                            raise ValueError(f"{tag} exceeds its verified size.")
                if apk.stat().st_size != file["size"] or sha256(apk) != file["sha256"]:
                    raise ValueError(f"Checksum/size mismatch for {apk.name}.")
                downloaded.append(apk)
            checksum = folder / "SHA256SUMS"
            checksum.write_text("".join(f"{file['sha256']}  {file['name']}\n" for file in files))
            assets = {a["name"]: a for a in release["assets"]}
            for file in [*downloaded, checksum]:
                if file.name not in assets:
                    endpoint = f"https://uploads.github.com/{release_path}/assets?name={urllib.parse.quote(file.name)}"
                    request = urllib.request.Request(endpoint, data=file.read_bytes(), method="POST", headers={
                        "Authorization": "Bearer " + os.environ["GH_TOKEN"],
                        "Content-Type": "application/octet-stream",
                        "Accept": "application/vnd.github+json",
                        "X-GitHub-Api-Version": "2022-11-28",
                        "User-Agent": "Qada-Tracker-Release",
                    })
                    with urllib.request.urlopen(request, timeout=180) as response:
                        assets[file.name] = json.load(response)
            assets = {a["name"]: a for a in api(release_path)["assets"]}
            for file in [*downloaded, checksum]:
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
                    with (verify / file.name).open("wb") as destination:
                        subprocess.run(["gh", "api", f"repos/{repo}/releases/assets/{asset['id']}", "--header", "Accept: application/octet-stream"], stdout=destination, check=True)
                    if sha256(verify / file.name) != sha256(file):
                        raise ValueError(f"Downloaded digest mismatch for {file.name}.")
            print(f"Verified private draft assets for {tag}", flush=True)
            summary = os.environ.get("GITHUB_STEP_SUMMARY")
            if summary:
                with open(summary, "a") as stream:
                    stream.write(f"- {tag}: APK and SHA256SUMS uploaded and verified.\n")


if __name__ == "__main__":
    main()
