from __future__ import annotations

import argparse
import logging
from pathlib import Path

import cv2
import numpy as np


def extract_embedding(image_path: str | Path, size: int = 128) -> np.ndarray:
    image = cv2.imread(str(image_path))
    if image is None:
        raise ValueError(f"Cannot read image: {image_path}")

    resized = cv2.resize(image, (size, size), interpolation=cv2.INTER_AREA)
    hsv = cv2.cvtColor(resized, cv2.COLOR_BGR2HSV)
    gray = cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY)

    hist_h = cv2.calcHist([hsv], [0], None, [32], [0, 180]).flatten()
    hist_s = cv2.calcHist([hsv], [1], None, [32], [0, 256]).flatten()
    hist_v = cv2.calcHist([hsv], [2], None, [32], [0, 256]).flatten()
    edges = cv2.Canny(gray, 80, 160)
    edge_hist = cv2.calcHist([edges], [0], None, [16], [0, 256]).flatten()

    vector = np.concatenate([hist_h, hist_s, hist_v, edge_hist]).astype(np.float32)
    norm = np.linalg.norm(vector)
    return vector if norm == 0 else vector / norm


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    if a.shape != b.shape:
        raise ValueError("Embedding shapes do not match")
    denom = np.linalg.norm(a) * np.linalg.norm(b)
    if denom == 0:
        return 0.0
    return float(np.dot(a, b) / denom)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract image embeddings and compare similarity.")
    parser.add_argument("image_a")
    parser.add_argument("image_b", nargs="?")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")

    emb_a = extract_embedding(args.image_a)
    logging.info("Embedding A shape: %s", emb_a.shape)
    if args.image_b:
        emb_b = extract_embedding(args.image_b)
        logging.info("Cosine similarity: %.4f", cosine_similarity(emb_a, emb_b))


if __name__ == "__main__":
    main()
