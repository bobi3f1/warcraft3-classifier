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
| Result | convnext_tiny_in22k, 17.9% error (int8 ONNX: 19.0%) | convnext_tiny_in22k, UI cropped, 768×300, 12 epochs: macro F1 0.644, 65% of units found, thr 0.2 (int8 ONNX: F1 0.641) on unseen map4 |

Version 1 history for the report: resnet18 on raw web images 52% error → 26% after hand-cleaning →
resnet34 21% → convnext_tiny_in22k 14–18%.

## Version 3 (started 2026-10-23): detect, then classify crops

Version 2 only reached 18% fully-correct screenshots and can't count, because a unit is ~50×60 px of a
1280×720 shot. Version 3 splits it: a detector finds one box per unit (gives the count), and a fast.ai
single-label classifier names each crop.

- Solo shots (`dataset_trigger_single.j` + `capture_single.py` → `data/single_units/`, one unit type, 1–3
  copies) place copies at known offsets from the camera target (rotation 90, angle of attack 304, distance =
  `zoom`). `unit_boxes()` in `warcraft3_unit_crops.ipynb` projects them to screen: F=908, CX=630, CY=286
  (measured from shots, checked on all three train maps, fliers included).
- `warcraft3_unit_crops.ipynb` → `data/unit_crops/` (3967 crops), convnext_tiny.fb_in22k 224, fp16,
  `fine_tune(8, 2e-3)`: **98.8%** on unseen `single-valid1` (167 crops, only 3–4 per class).
  Map-2 frames excluded for the warning text are reused when the crop box doesn't touch the text.
- On this GTX 1080 Ti training sometimes hits NaN at a random batch (not LR-related, pretrained gammas
  are already ~54); keep `SaveModelCallback` + `TerminateOnNaNCallback`.
- `warcraft3_detector.ipynb` (user approved ultralytics, 2026-10-23): YOLO26s (`yolo26s.pt`, NMS-free),
  boxes from `screen_box(x, y, zoom)` = same box as the crops, worker icon hidden (`hide_worker_icon`, must
  also be applied at inference), dataset in `data/yolo/`, run in `models/detector/`. imgsz 1280, batch 4
  (batch 8 overflows 11 GB and crawls), 30 epochs ≈ 7.5 min/epoch, mosaic turns solo shots into mixed
  scenes. Evaluates count-correct / whole-image-correct on `single-valid1` and set-match on old map4.
  Scripts using ultralytics outside a notebook need `if __name__ == '__main__':` on Windows.
  Result (best = epoch 20; epoch 26 died with "CUDA error: illegal instruction" — GPU looks unstable):
  solo valid whole-image correct 93.4% → 95.8% with one-box-per-unit merge (IoU>0.5); map4 mixed set-match
  37.2% → 42.8% with merge + crop classifier relabel (v2: 18%), units found 70.5%, wrong 134 (v2: 900).
  conf 0.3 picked on the same solo valid map. `find_units()` in the notebook = the full pipeline.
- `dataset_trigger.j` now fixes camera rotation/AoA and writes `UNIT|name|x|y|zoom` per unit (x, y relative
  to the camera target); `capture.py` writes those to `data/units.csv` (labels.csv unchanged). Not yet
  compiled/run in the game.
- Still to do: new mixed captures with positions, a full solo validation map and a test map, combine
  detector + crop classifier if the detector's classes are weaker, ONNX export and a new site page.
- The Codex-era untracked notebooks (`warcraft3_single_units`, `_focus_retrain`, `_clean_small_retrain`) and
  `prepare_clean_retrain.py` were never run; superseded by this plan.

## How the pieces fit

- `game_capture/dataset_trigger.j` — JASS, pasted into World Editor as the custom text of the
  "Melee Initialization" trigger of a Blizzard melee map. Every 1.5 s: removes the old scene, puts 1–6 random
  units (51 unit ids → 48 classes; druid forms, Berserker share a class) side by side on a random walkable spot,
  random owner/facing/animation, `Aloc` so nothing fights, sometimes an unlabeled building, random zoom
  (1350–1900) and time of day, then writes the unit names with `PreloadGenEnd` to
  `Documents\Warcraft III\CustomMapData\wc3dataset\shot_<n>.txt`. Before the first scene it creates every
  unit/building once so the models are loaded (otherwise the game freezes on a new model and the screenshot shows
  the old scene). Spots with trees/destructables in the scene area are rejected (Northrend map had units hidden
  in forests). First trial on 2026-10-17 (Reforged 3.0, Classic graphics) worked apart from that.
- `game_capture/capture.py` — waits for each shot file, screenshots the main monitor (mss), saves
  `data/screens/<map>_<n>.jpg` (1280×720) and appends `fname,labels` (labels joined with `;`) to
  `data/labels.csv`, plus one `fname,label,x,y,zoom` row per unit to `data/units.csv`. Re-grabs (then skips) if the map area hasn't changed since the last shot. Starts from whichever shot appears first after it starts.
- `warcraft3_screenshots.ipynb` — reads `data/labels.csv`, validation = one whole map (`is_valid` column +
  `ColSplitter`), `Resize((360, 640), method='squish')`, no rotate/zoom augmentation, convnext_tiny_in22k,
  threshold picked by F1 on validation, per-unit recall/precision table, then exports the website files.
  Tested end-to-end on fake composited data (resnet18, 1 epoch).
- `docs/` — GitHub Pages site. The model runs **in the browser** with onnxruntime-web 1.30.0 (Hugging Face free
  Spaces give a 403 "cpu-basic quota limit", so no Python server). `docs/model.json` tells the page the labels,
  input width/height, `multi_label` and `threshold`, optional `crop_top`/`crop_bottom` (fractions of the image
  height, same as `crop_ui` in the notebook) and lists `docs/examples/` (+ `example_labels` so the gallery can
  mark right/wrong/missed — the notebook export still has to write that key). The page works for both versions.
  Two styles sharing `docs/app.js`: `index.html` is a Jekyll page (`layout: page`) using the separate theme repo
  `bobi3f1/wc3-nightelf-theme` via `remote_theme` in `docs/_config.yml` (like tinypets/alembic in Lesson 2);
  `moonlit.html` is plain HTML. No Ruby here, so `index.html` only renders on GitHub Pages; locally test
  `moonlit.html` with http.server.
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
   (`cy + GetRandomReal(-300, 150)`, x spread 1100), zoom and sleep time in `dataset_trigger.j` if needed.
   If World Editor reports a JASS error, fix it (the script was written without access to the game).
3. Delete the trial files, then capture 4–6 maps with different tilesets (~800 shots each).
   **Done 2026-10-17:** 3161 shots — map1 Lordaeron Summer (dataset_1) 800, map2 Northrend (dataset_3) 766,
   map3 Ashenvale (dataset_4) 799, map4 Lordaeron Summer, other map (dataset_5) 796 = validation map.
   Removed to `data/rejected/`: first Northrend run (units hidden in forests, before the tree check), 34 Northrend
   shots with ice-crystal doodads over units, 2 shots taken while quitting the game.
4. Optionally collect 20–50 real gameplay screenshots in `my_screenshots/` (honest real-world test).
5. Run `warcraft3_screenshots.ipynb` on the GPU, check the per-unit table, update the README results section
   with real numbers, test the site locally (`python -m http.server 8000 --directory docs`), commit and push.
6. Enable GitHub Pages: Settings → Pages → Deploy from branch `main`, folder `/docs`.
