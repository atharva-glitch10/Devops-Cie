"""Poll a URL until it returns HTTP 200, or exit 1. Used by the Jenkins pipeline.

Usage: python scripts/smoke_test.py http://localhost:5055/health
"""
import sys
import time
import urllib.request


def main():
    url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:5000/health"
    for attempt in range(1, 16):
        try:
            with urllib.request.urlopen(url, timeout=3) as resp:
                if resp.status == 200:
                    print(f"OK ({resp.status}) after {attempt} attempt(s): {resp.read().decode()}")
                    return 0
        except OSError as exc:
            print(f"Attempt {attempt}: not ready yet ({exc})")
        time.sleep(2)
    print(f"FAILED: {url} did not become healthy", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
