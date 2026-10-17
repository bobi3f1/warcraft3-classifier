# Warcraft III unit classifier — notes for Claude

University exercise (TU Sofia, ТГД): an image classifier built the fast.ai way
(Practical Deep Learning for Coders, Lessons 1–3 + fastbook ch. 6). The student presents it to the teacher,
so they must be able to explain every line.

## Rules for this project

- **Keep the Python as simple as in the fast.ai lessons**: notebooks, `from fastai.vision.all import *`,
  `DataBlock`, `vision_learner`, `fine_tune`. No packages/classes/config systems. A previous over-engineered
  version was deliberately thrown away.
- README and notebook explanations are in **Bulgarian**; code and code comments in English.
- Only images **from the game itself** (Classic graphics) for version 2 — no internet images.
- Report results honestly (validation numbers, limitations).

## Two versions

| | Version 1 (done) | Version 2 (current work) |
|---|---|---|
| Notebook | `warcraft3_classifier.ipynb` | `warcraft3_screenshots.ipynb` |
| Input → output | crop of one unit → 1 of 8 units | whole game screenshot → which of 48 units are present |
| Data | web images (DuckDuckGo), hand-cleaned; not in the repo | screenshots made by the game via World Editor map |
| Type | single-label, softmax | multi-label (`MultiCategoryBlock`), sigmoid + threshold |
| Result | convnext_tiny_in22k, 17.9% error (int8 ONNX: 19.0%) | not trained yet |

Version 1 history for the report: resnet18 on raw web images 52% error → 26% after hand-cleaning →
resnet34 21% → convnext_tiny_in22k 14–18%.

## How the pieces fit

- `game_capture/dataset_trigger.j` — JASS, pasted into World Editor as the custom text of the
  "Melee Initialization" trigger of a Blizzard melee map. Every 1.5 s: removes the old scene, puts 1–6 random
  units (51 unit ids → 48 classes; druid forms, Berserker share a class) side by side on a random walkable spot,
  random owner/facing/animation, `Aloc` so nothing fights, sometimes an unlabeled building, random zoom
  (1350–1900) and time of day, then writes the unit names with `PreloadGenEnd` to
  `Documents\Warcraft III\CustomMapData\wc3dataset\shot_<n>.txt`. **Not yet tested in the real game.**
- `game_capture/capture.py` — waits for each shot file, screenshots the main monitor (mss), saves
  `data/screens/<map>_<n>.jpg` (1280×720) and appends `fname,labels` (labels joined with `;`) to
  `data/labels.csv`. Tested with a simulator. Starts from whichever shot appears first after it starts.
- `warcraft3_screenshots.ipynb` — reads `data/labels.csv`, validation = one whole map (`is_valid` column +
  `ColSplitter`), `Resize((360, 640), method='squish')`, no rotate/zoom augmentation, convnext_tiny_in22k,
  threshold picked by F1 on validation, per-unit recall/precision table, then exports the website files.
  Tested end-to-end on fake composited data (resnet18, 1 epoch).
- `docs/` — GitHub Pages site. The model runs **in the browser** with onnxruntime-web 1.30.0 (Hugging Face free
  Spaces give a 403 "cpu-basic quota limit", so no Python server). `docs/model.json` tells the page the labels,
  input width/height, `multi_label` and `threshold`, and lists `docs/examples/`. The page works for both
  versions without code changes.
- Export details that matter: `torch.onnx.export(..., dynamo=False)` (the dynamo exporter's output breaks
  quantization), then `quantize_dynamic(..., QuantType.QInt8, op_types_to_quantize=['MatMul','Gemm'],
  per_channel=True)` — per-channel kept accuracy (82.1% → 81.0%); without it accuracy fell to 77.4%.
  Full-size ONNX matched PyTorch on 100% of images. GitHub's file limit is 100 MB, so `model.pkl` and the
  full-size `model.onnx` are git-ignored; only `docs/model.onnx` (~35 MB) is committed.
- `app.py` — Lesson-2-style Gradio app for local use only.

## Next steps (on the gaming PC with a GPU)

1. Set up Python 3.12/3.13 venv, CUDA PyTorch from pytorch.org, then `pip install -r requirements.txt`.
2. **Short trial first:** prepare one map (README "Версия 2", steps 2–3), run
   `python game_capture/capture.py --map test --shots 30`, Test Map, then look at a few images in
   `data/screens/` together with `data/labels.csv`. Check: units visible and not hidden under the bottom UI
   panel, not too small, labels match what's on screen, Classic graphics, no fights/creeps. Tune placement
   (`cy + GetRandomReal(-150, 300)`, x spread 1100), zoom and sleep time in `dataset_trigger.j` if needed.
   If World Editor reports a JASS error, fix it (the script was written without access to the game).
3. Delete the trial files, then capture 4–6 maps with different tilesets (~800 shots each).
4. Optionally collect 20–50 real gameplay screenshots in `my_screenshots/` (honest real-world test).
5. Run `warcraft3_screenshots.ipynb` on the GPU, check the per-unit table, update the README results section
   with real numbers, test the site locally (`python -m http.server 8000 --directory docs`), commit and push.
6. Enable GitHub Pages: Settings → Pages → Deploy from branch `main`, folder `/docs`.
