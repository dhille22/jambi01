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
    parser = argparse.ArgumentParser(description="Realtime webcam classification.")
    parser.add_argument("--model", default="runs/classifier/best.keras")
    parser.add_argument("--camera", type=int, default=0)
    parser.add_argument("--imgsz", type=int, default=224)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")

    model_path = Path(args.model)
    if not model_path.exists():
        raise FileNotFoundError(f"Model not found: {model_path.resolve()}")

    model = tf.keras.models.load_model(model_path)
    cap = cv2.VideoCapture(args.camera)
    if not cap.isOpened():
        raise RuntimeError("Cannot open webcam")

    logging.info("Press q to exit.")
    while True:
        ok, frame = cap.read()
        if not ok:
            break

        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        resized = cv2.resize(rgb, (args.imgsz, args.imgsz), interpolation=cv2.INTER_AREA)
        batch = np.expand_dims(resized.astype(np.float32), axis=0)

        start = time.perf_counter()
        probabilities = model.predict(batch, verbose=0)[0]
        latency_ms = (time.perf_counter() - start) * 1000
        index = int(np.argmax(probabilities))
        label = CLASS_NAMES[index]
        confidence = float(probabilities[index])

        cv2.putText(
            frame,
            f"{label} {confidence:.2f} | {latency_ms:.1f} ms",
            (16, 32),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (0, 255, 0),
            2,
        )
        cv2.imshow("Jambi Facility Damage Classification", frame)
        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
