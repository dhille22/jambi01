from __future__ import annotations

import argparse
import logging
from pathlib import Path

import cv2

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Resize and validate image classification dataset."
    )
    parser.add_argument("--input", default="dataset_classifier")
    parser.add_argument("--output", default="dataset_classifier_preprocessed")
    parser.add_argument("--size", type=int, default=224)
    return parser.parse_args()


def process_split(input_root: Path, output_root: Path, split: str, size: int) -> None:
    split_dir = input_root / split
    if not split_dir.exists():
        logging.warning("Split not found: %s", split_dir)
        return

    for class_dir in split_dir.iterdir():
        if not class_dir.is_dir():
            continue

        out_class_dir = output_root / split / class_dir.name
        out_class_dir.mkdir(parents=True, exist_ok=True)

        for image_path in class_dir.glob("*"):
            if image_path.suffix.lower() not in IMAGE_EXTENSIONS:
                continue

            image = cv2.imread(str(image_path))
            if image is None:
                logging.warning("Skipping unreadable image: %s", image_path)
                continue

            resized = cv2.resize(image, (size, size), interpolation=cv2.INTER_AREA)
            cv2.imwrite(str(out_class_dir / image_path.name), resized)


def main() -> None:
    args = parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
    input_root = Path(args.input)
    output_root = Path(args.output)

    for split in ("train", "valid", "test"):
        process_split(input_root, output_root, split, args.size)

    logging.info("Preprocessed dataset saved to %s", output_root.resolve())


if __name__ == "__main__":
    main()
