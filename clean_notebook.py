import argparse
import json
import os
from pathlib import Path


def clean_notebook(notebook_path: Path, cleaned_path: Path, remove_outputs: bool = True) -> None:
    """Load a Jupyter notebook, remove widget metadata and optionally clear outputs.

    Args:
        notebook_path: Path to the input .ipynb file.
        cleaned_path: Path to write the cleaned notebook.
        remove_outputs: If True, remove cell outputs and reset execution count.
    """
    if not notebook_path.exists():
        raise FileNotFoundError(f"Notebook not found at {notebook_path}")

    with notebook_path.open('r', encoding='utf-8') as f:
        notebook = json.load(f)

    # Remove any 'widgets' keys anywhere in the notebook structure
    def remove_key_recursive(obj, key_to_remove: str):
        if isinstance(obj, dict):
            # pop the key if present
            if key_to_remove in obj:
                obj.pop(key_to_remove, None)
            # recurse into values
            for v in list(obj.values()):
                remove_key_recursive(v, key_to_remove)
        elif isinstance(obj, list):
            for item in obj:
                remove_key_recursive(item, key_to_remove)

    remove_key_recursive(notebook, "widgets")

    # Optionally clear cell outputs & execution counts
    if remove_outputs:
        for cell in notebook.get("cells", []):
            if isinstance(cell, dict):
                cell.pop("outputs", None)
                # only set execution_count if the key exists or was used
                if "execution_count" in cell:
                    cell["execution_count"] = None
                # keep other useful metadata but ensure it's a dict
                cell_meta = cell.get("metadata", {})
                if not isinstance(cell_meta, dict):
                    cell["metadata"] = {}

    # Write cleaned notebook
    with cleaned_path.open('w', encoding='utf-8') as f:
        json.dump(notebook, f, indent=2)


def main():
    parser = argparse.ArgumentParser(description="Clean a Jupyter notebook by removing widget metadata and outputs.")
    parser.add_argument("input", help="Path to the input .ipynb file", nargs='?',
                        default=str(Path(__file__).with_name('Notebook').joinpath('ML_experiments.ipynb')))
    parser.add_argument("-o", "--output", help="Path to the cleaned notebook", default="cleaned_ML_experiments.ipynb")
    parser.add_argument("--keep-outputs", help="Do not remove cell outputs", action="store_true")

    args = parser.parse_args()

    input_path = Path(args.input).expanduser().resolve()
    output_path = Path(args.output).expanduser().resolve()

    try:
        clean_notebook(input_path, output_path, remove_outputs=not args.keep_outputs)
        print(f"✅ Notebook cleaned successfully! Saved as {output_path}")
    except Exception as e:
        print(f"⚠️ Error while cleaning: {e}")


if __name__ == "__main__":
    main()
