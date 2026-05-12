import os
import subprocess
import sys
from pathlib import Path

def main():
    raw_path = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("STAGING_SSH_KEY_PATH", "").strip()
    if not raw_path:
        raise SystemExit("Provide the output path via argv[1] or STAGING_SSH_KEY_PATH")

    key_path = Path(raw_path).expanduser().resolve()
    repo_root = Path(os.getcwd()).resolve()
    if repo_root in key_path.parents:
        raise SystemExit("Refusing to write SSH keys inside the repository")

    key_path.parent.mkdir(parents=True, exist_ok=True)
    if key_path.exists():
        key_path.unlink()
    public_key_path = Path(str(key_path) + ".pub")
    if public_key_path.exists():
        public_key_path.unlink()

    cmd = ["ssh-keygen", "-t", "ed25519", "-N", "", "-f", str(key_path)]
    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    print(f"STDOUT: {result.stdout}")
    print(f"STDERR: {result.stderr}")
    print(f"Exit Code: {result.returncode}")

if __name__ == "__main__":
    main()
