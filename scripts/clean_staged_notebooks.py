import subprocess
import json
from pathlib import Path
import sys

# Import the clean function from the repository's script
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from clean_notebook import clean_notebook


def get_staged_files():
    """Return a list of staged files (git diff --cached --name-only)."""
    out = subprocess.check_output(["git", "diff", "--cached", "--name-only"]).decode().splitlines()
    return [Path(p) for p in out if p.endswith('.ipynb')]


def main():
    staged = get_staged_files()
    if not staged:
        return 0

    for nb in staged:
        nb_path = nb.resolve()
        cleaned_path = nb_path.with_suffix(nb_path.suffix + '.cleaned')
        try:
            clean_notebook(nb_path, cleaned_path, remove_outputs=True)
            cleaned_path.replace(nb_path)
            # re-stage the cleaned file
            subprocess.check_call(["git", "add", str(nb_path)])
            print(f"Cleaned and re-staged {nb_path}")
        except Exception as e:
            print(f"Failed to clean {nb_path}: {e}")
            return 1

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
