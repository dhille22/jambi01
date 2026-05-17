from __future__ import annotations

import argparse
import json
import logging
import time
from pathlib import Path

import tensorflow as tf

CLASS_NAMES = [
    "lubang_jalan",
    "drainase_rusak",
    "penerangan_rusak",
    "trotoar_rusak",
    "sampah_menumpuk",
]

IMAGE_EXTENSIONS = {".bmp", ".gif", ".jpeg", ".jpg", ".png"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Train MobileNetV3 image classifier for Kota Jambi facility damage."
    )
    parser.add_argument("--dataset", default="dataset_classifier")
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--fine-tune-epochs", type=int, default=20)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--imgsz", type=int, default=224)
    parser.add_argument("--learning-rate", type=float, default=1e-3)
    parser.add_argument("--fine-tune-learning-rate", type=float, default=1e-5)
    parser.add_argument("--output", default="runs/classifier")
    return parser.parse_args()


def build_dataset(root: Path, split: str, image_size: int, batch_size: int) -> tf.data.Dataset:
    split_dir = root / split
    if not split_dir.exists():
        raise FileNotFoundError(f"Dataset split not found: {split_dir.resolve()}")
    _validate_split(split_dir, split)

    dataset = tf.keras.utils.image_dataset_from_directory(
        split_dir,
        labels="inferred",
        label_mode="categorical",
        class_names=CLASS_NAMES,
        image_size=(image_size, image_size),
        batch_size=batch_size,
        shuffle=split == "train",
        seed=42,
    )

    return dataset.prefetch(tf.data.AUTOTUNE)


def _validate_split(split_dir: Path, split: str) -> None:
    missing = [class_name for class_name in CLASS_NAMES if not (split_dir / class_name).exists()]
    if missing:
        raise FileNotFoundError(
            f"Dataset split '{split}' is missing class folders: {', '.join(missing)}"
        )

    empty = []
    for class_name in CLASS_NAMES:
        class_dir = split_dir / class_name
        image_count = sum(
            1 for item in class_dir.iterdir() if item.suffix.lower() in IMAGE_EXTENSIONS
        )
        if image_count == 0:
            empty.append(str(class_dir))

    if empty:
        raise ValueError(
            "Dataset belum berisi gambar untuk training classifier.\n"
            "Isi minimal beberapa gambar .jpg/.jpeg/.png pada folder berikut:\n"
            + "\n".join(empty)
        )


def build_model(image_size: int, class_count: int) -> tf.keras.Model:
    inputs = tf.keras.Input(shape=(image_size, image_size, 3), name="image")
    x = tf.keras.layers.Rescaling(1.0 / 127.5, offset=-1.0, name="mobilenet_preprocess")(inputs)
    x = tf.keras.layers.RandomFlip("horizontal", name="augment_flip")(x)
    x = tf.keras.layers.RandomRotation(0.04, name="augment_rotation")(x)
    x = tf.keras.layers.RandomZoom(0.12, name="augment_zoom")(x)
    x = tf.keras.layers.RandomContrast(0.15, name="augment_contrast")(x)

    base_model = tf.keras.applications.MobileNetV3Large(
        include_top=False,
        weights="imagenet",
        input_shape=(image_size, image_size, 3),
        include_preprocessing=False,
    )
    base_model.trainable = False

    x = base_model(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D(name="global_pool")(x)
    x = tf.keras.layers.Dropout(0.25, name="dropout")(x)
    outputs = tf.keras.layers.Dense(class_count, activation="softmax", name="classification")(x)

    model = tf.keras.Model(inputs, outputs, name="jambi_facility_mobilenetv3")
    model.base_model = base_model  # type: ignore[attr-defined]
    return model


def compile_model(model: tf.keras.Model, learning_rate: float) -> None:
    model.compile(
        optimizer=tf.keras.optimizers.AdamW(learning_rate=learning_rate, weight_decay=1e-4),
        loss="categorical_crossentropy",
        metrics=[
            tf.keras.metrics.CategoricalAccuracy(name="accuracy"),
            tf.keras.metrics.Precision(name="precision"),
            tf.keras.metrics.Recall(name="recall"),
        ],
    )


def main() -> None:
    args = parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")

    dataset_root = Path(args.dataset).resolve()
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    train_ds = build_dataset(dataset_root, "train", args.imgsz, args.batch)
    valid_ds = build_dataset(dataset_root, "valid", args.imgsz, args.batch)

    model = build_model(args.imgsz, len(CLASS_NAMES))
    compile_model(model, args.learning_rate)

    callbacks = [
        tf.keras.callbacks.ModelCheckpoint(
            output_dir / "best.keras",
            monitor="val_accuracy",
            save_best_only=True,
            mode="max",
        ),
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy",
            patience=8,
            mode="max",
            restore_best_weights=True,
        ),
        tf.keras.callbacks.CSVLogger(output_dir / "training_log.csv"),
    ]

    logging.info("Training MobileNetV3 classifier with frozen ImageNet backbone.")
    start = time.perf_counter()
    history = model.fit(train_ds, validation_data=valid_ds, epochs=args.epochs, callbacks=callbacks)

    logging.info("Fine-tuning upper MobileNetV3 layers.")
    base_model = model.base_model  # type: ignore[attr-defined]
    base_model.trainable = True
    for layer in base_model.layers[:-35]:
        layer.trainable = False

    compile_model(model, args.fine_tune_learning_rate)
    fine_history = model.fit(
        train_ds,
        validation_data=valid_ds,
        epochs=args.epochs + args.fine_tune_epochs,
        initial_epoch=len(history.history["loss"]),
        callbacks=callbacks,
    )
    elapsed = time.perf_counter() - start

    model.save(output_dir / "final.keras")
    with (output_dir / "labels.txt").open("w", encoding="utf-8") as file:
        file.write("\n".join(CLASS_NAMES) + "\n")
    with (output_dir / "history.json").open("w", encoding="utf-8") as file:
        json.dump(
            {
                "initial": history.history,
                "fine_tune": fine_history.history,
                "elapsed_seconds": elapsed,
                "classes": CLASS_NAMES,
            },
            file,
            indent=2,
        )

    logging.info("Training complete in %.2f seconds", elapsed)
    logging.info("Best model: %s", (output_dir / "best.keras").resolve())
    logging.info("Final model: %s", (output_dir / "final.keras").resolve())


if __name__ == "__main__":
    main()
