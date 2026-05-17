from __future__ import annotations

import argparse
import logging
from pathlib import Path

import numpy as np
import tensorflow as tf
from sklearn.metrics import classification_report, confusion_matrix

from train import CLASS_NAMES, build_dataset


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate MobileNetV3 image classifier.")
    parser.add_argument("--model", default="runs/classifier/best.keras")
    parser.add_argument("--dataset", default="dataset_classifier")
    parser.add_argument("--split", default="valid", choices=["valid", "test"])
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--imgsz", type=int, default=224)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")

    model_path = Path(args.model)
    if not model_path.exists():
        raise FileNotFoundError(f"Model not found: {model_path.resolve()}")

    model = tf.keras.models.load_model(model_path)
    dataset = build_dataset(Path(args.dataset).resolve(), args.split, args.imgsz, args.batch)

    y_true: list[int] = []
    y_pred: list[int] = []

    for images, labels in dataset:
        probabilities = model.predict(images, verbose=0)
        y_true.extend(np.argmax(labels.numpy(), axis=1).tolist())
        y_pred.extend(np.argmax(probabilities, axis=1).tolist())

    report = classification_report(y_true, y_pred, target_names=CLASS_NAMES, digits=4)
    matrix = confusion_matrix(y_true, y_pred)

    logging.info("Classification report:\n%s", report)
    logging.info("Confusion matrix:\n%s", matrix)


if __name__ == "__main__":
    main()
