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
- **Capture finished 2026-10-28** (shots with units / units): train mixed-train1(b)-bloodvenom 777/3651,
  mixed-train2-icecrown 813/3640, battle-train1b 422/4378, -1c 238/2524 (game froze: unpause bug, fixed),
  -1d 533/6555, battle-train1 70/535 (one Undead base only, weak); valid mixed-valid1-divide 400/1846;
  test mixed-test1-dustwallow 400/1782 (new trigger, z present). Total 3653 / 24911 + 2958 solo shots.
  data/screens 2.0 GB, single_units/screens 1.3 GB. No real screenshots yet (my_screenshots/ empty).
- Audit 2026-10-28 before Kaggle: no broken/duplicate/stalled files; moved to `data/rejected/`: all of
  `battle-train1` (Discord overlay + webcam in every shot, one base) and 3 desktop frames (Alt+Tab).
  All 48 classes in train/valid/test (min 130 train units). ~20% of battle units are off screen and dropped
  by `visible()`. Known label noise: battle Wisps harvesting lumber under tree canopy (771 of 13448 battle
  labels are Wisps; a future trigger could skip units with a tree right next to them).
  Notebook data prep run locally on the full data: 26,013 units (21,870 train), YOLO 5561 train / 567 val /
  400 test images; show_batch and YOLO train_batch checked. `kaggle_dataset.zip` 2.7 GB, 7339 files.
  No Kaggle API token on this PC (no ~/.kaggle/kaggle.json, no CLI) → upload through the browser.
- Goal set by the user (2026-10-23): 98–99% fully-correct on **real** in-game screenshots, training on Kaggle.
  Main failure so far: misses when units stand close (solo shots never show that); 336/455 wrong map4
  shots were misses only; exact match 81% with 1 unit type → 0% with 6.
- `dataset_trigger.j` (rewritten, NOT yet compiled/run in game): modes row / crowded group / two armies
  fighting (BlzSetUnitMaxHP 100000, attack-move) / army of one type; 1–8 units; unlabeled heroes (16 ids),
  building, spell effects, selection circles; units paused and positions logged with GetUnitX/Y right before
  the marker (the game pushes overlapping units apart, so requested positions were wrong).
- 2026-10-24: the rewritten `dataset_trigger.j` compiled and ran on (8)Bloodvenom Falls → `mixed-train1-bloodvenom`
  (~3.5 s/shot); boxes checked on the first shots, fights/armies/selection circles visible. The game was
  closed after **177 shots** (806 units); a new run must use a new `--map` name (same name would overwrite
  the jpgs and duplicate CSV rows). 2026-10-25: `mixed-train1b-bloodvenom` 600 shots (2845 units, 0 skipped);
  Bloodvenom total 777 shots / 3651 units. Test Map starts from a fixed seed, so shot 0 repeats each run.
  That run logs no `z`; the trigger now also writes `z` (terrain height vs camera target) for later maps.
- `mixed-valid1-divide` ((12)Divide and Conquer, validation map, old trigger → z = 0): 400 shots / 1846 units.
- 2026-10-28: `mixed-train2-icecrown` ((12)Icecrown) done: 813 shots / 3640 units, 0 skipped; that map has the older trigger (no `z`), shots
  ~9–34 lost during a collector restart. `capture.py` now upgrades an old 5-column units.csv to 6 columns
  (z = 0) when it starts. Battle trial on Richman's Garden: only ONE computer slot was set → 76 shots of one
  Undead base (`battle-train1_*`, not yet renamed); collector died with exit 4. A webcam overlay (the user's
  face) was in the bottom-left corner of those battle shots — must be closed before capturing.
- World Editor **Test Map only lets player 2 join** (players.txt: computers 3–8 playing=0). Battle maps must
  be started from Warcraft III → Single Player → Custom Game with slots 2–8 set to Computer. Running that
  way since 2026-10-28 as `battle-train1b` (Richman's Garden, all 8 bases, z = 0 there, positions checked
  at full resolution: box centres land on the units). Discord overlay was turned off.
- `dataset_trigger_battle.j` (compiled and ran once, see above): computer players play real melee (MeleeStarting* without
  MeleeInitVictoryDefeat, player 1's units removed), camera jumps to fights every ~5 s, pauses only non-building units near the camera (PauseAllUnitsBJ broke the Night Elf AI), hashtable type lookup (the 51-way search hit the op limit late game),
  logs every visible (IsUnitVisible / not IsUnitInvisible / not hidden) labeled unit with `z`.
  `capture.py --units-csv data/battle_units.csv` (6 columns incl. z); notebooks read it as source 'battle'.
  `screen_box(x, y, zoom, z)` handles terrain height.
- Map names decide the split everywhere: `valid` / `test` in the name, `trial` = ignored, else train.
- Both notebooks build one unit table from solo (projected) + `data/units.csv` (projected, `visible()` drops
  off-screen / under-panel units) + `my_screenshots/{train,test}/labels/*.txt` (hand-checked YOLO txt,
  class = line in `my_screenshots/classes.txt` = sorted vocab). Real train images ×4 in YOLO data.
  ROOT/WORK switch for Kaggle (`/kaggle/input` rglob for `single_units/labels.csv`, write `/kaggle/working`).
  Detector: yolo26m, EPOCHS 60, `time=HOURS` 10, batch 4/GPU, device = all GPUs (T4×2); conf and merge-IoU
  picked on valid; reports valid / test / real-test; exports ONNX + thresholds.json.
- `prelabel_screenshots.py` writes model drafts to `labels_draft/` (never read by notebooks) for review in
  makesense.ai; `make_kaggle_dataset.py` → `kaggle_dataset.zip`.
- Kaggle 2026-10-28: crop notebook ran (T4×2, 24 min): valid_loss 1.76→0.63, **test mixed crops 84.1% of 1782** (crowded crops hold several units). Detector notebook now lets validation decide USE_CLASSIFIER (YOLO only vs YOLO + classifier).
- Kaggle 2026-10-30: detector ran (yolo26m, `time=10` h gave 94 epochs, ~6.5 min each on T4×2): validation P 0.976,
  R 0.911, mAP50 0.947, mAP50-95 0.724. Picked on valid: conf 0.5, no merge (iou 1.01), **use_classifier False**.
  **Test Dustwallow 63.8% exact (145/400 wrong)**, map4 names only 92.0% of 796 (v2 18%, solo detector 42.8%).
  Not the 98–99% goal, and still no real screenshots. The score table is displayed output, so it isn't in the
  Kaggle log: use the notebook's Output or recompute. `best.onnx` (78.5 MB) and `best.zip` (really `best.pt`,
  pickle) were downloaded to the repo root; don't commit them.
- Local check with `best.onnx` on CPU, 0.73 s/image (input fixed at 1280×1280): test 61.75% (153 wrong), valid
  mixed 64.75%, solo valid 100%. Use `device='cpu'` and `YOLO_AUTOINSTALL=false`, otherwise ultralytics installs
  `onnxruntime-gpu` into `.venv`, and it can't load here (needs CUDA 13). A conf/iou grid up to conf 0.8 gains
  nothing on valid.
- Why test is low: closest pair under ~50 px 34.0% (162 shots), ~50–100 px 70.8% (106), over ~100 px or one unit
  88.6% (132); 1 unit 95.7% → 8 units 36.4%. List level: 185 missed, 58 extra of 1782. Modes 1 and 3 of
  `dataset_trigger.j` scatter `Aloc` units with no collision, so they stack; by eye on 12 miss-only shots, 7 missed
  units can't be seen or counted, 3 partly hidden, 2 real misses. So retraining on the same data won't fix this.
- **The trained detector is NOT NMS-free:** `best.pt` has `end2end False` and `best.onnx` metadata too, despite
  `end2end: True` in the yaml. ONNX output is raw (1, 52, 33600): centre x, y, width, height in 1280×1280 pixels
  (image pasted at y = 280) + 48 sigmoid scores, with many anchors firing per unit. Ultralytics hid this by running
  NMS (iou 0.7, per class) in `predict`, so a page must do that too. `classifier_app.py` does it in plain numpy
  and matched ultralytics on 40/40 validation shots.
- 2026-10-30, 70 good shots (`good_screenshots_70.csv`, `test_good_screenshots.py`): from the test map, spacing
  ≥ ~100 px and nothing cut off, random order, effect/building-covered shots rejected by eye, all fixed before
  scoring; 15 one-unit + 55 multi-unit, 183 units, 44/48 types. **65/70 = 92.9% exact (Wilson 95% about 84–97%),
  names only 94.3%, count 94.3%, units 180/183 = 98.4%.** Namer chosen on 119 rule-only good valid shots: YOLO names
  93.3% exact, local solo-only `data/unit_crops/unit_classifier.pkl` 68.9% (the Kaggle pkl isn't on this PC).
- Still to do: `battle-test1` on an unseen map (real collision, automatic labels; evaluate locally, no Kaggle
  needed), then real screenshots. A site page needs `predict` + NMS ported to `docs/app.js`, and a retest on the
  same 70 if the model is quantized (78.5 MB now).
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
- `detector_app.py` — Gradio tester for Version 3: any screenshot → boxes, names and counts from `best.onnx` on CPU
  (`device='cpu'` stops ultralytics installing `onnxruntime-gpu`). launch.json name `detector-app`, port 7860.
  PNG and TGA at 1920×1080 checked through its API (`/find_units`). Examples are listed at start, so restart it
  to see new `battle-test1` shots. While `capture.py` runs, keep it off the main monitor: capture grabs that screen.
- `classifier_app.py` — same idea, onnxruntime only (no ultralytics): each unit's crop, best guess and next two
  guesses. launch.json name `classifier-app`, also port 7860, so run one app at a time.

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
