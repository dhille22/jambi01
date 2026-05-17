from __future__ import annotations

import argparse
import logging
import time
from pathlib import Path

import cv2
import numpy as np
import tensorflow as tf

from train import CLASS_NAMES


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run image classification inference.")
    parser.add_argument("--model", default="runs/classifier/best.keras")
    parser.add_argument("--source", required=True)
    parser.add_argument("--imgsz", type=int, default=224)
    return parser.parse_args()


def load_image(path: str | Path, image_size: int) -> np.ndarray:
    image = cv2.imread(str(path))
    if image is None:
        raise ValueError(f"Cannot read image: {path}")
    rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    resized = cv2.resize(rgb, (image_size, image_size), interpolation=cv2.INTER_AREA)
    return np.expand_dims(resized.astype(np.float32), axis=0)


def main() -> None:
    args = parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")

    model_path = Path(args.model)
    if not model_path.exists():
        raise FileNotFoundError(f"Model not found: {model_path.resolve()}")

    model = tf.keras.models.load_model(model_path)
    source = Path(args.source)
    images = sorted(source.glob("*")) if source.is_dir() else [source]

    for image_path in images:
        start = time.perf_counter()
        batch = load_image(image_path, args.imgsz)
        probabilities = model.predict(batch, verbose=0)[0]
        latency_ms = (time.perf_counter() - start) * 1000
        index = int(np.argmax(probabilities))

        logging.info(
            "%s | label=%s confidence=%.4f latency=%.2fms",
            image_path,
            CLASS_NAMES[index],
            float(probabilities[index]),
            latency_ms,
        )


if __name__ == "__main__":
    main()
