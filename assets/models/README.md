Place the fine-tuned MobileNetV3 image classification TFLite model here:

`facility_classifier.tflite`

The Flutter app intentionally falls back to dummy inference when this file is
not present, so UI and Supabase workflows can be developed before model
fine-tuning is complete.
