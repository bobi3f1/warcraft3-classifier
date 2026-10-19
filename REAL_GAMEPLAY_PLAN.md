# Plan toward 90% fully correct Warcraft III screenshots

Prepared 19 October 2026. **90% is the acceptance target, not a promised outcome from a fixed number of images or epochs.** The work is complete only when a frozen model passes an independent real-game test. If it does not pass, we collect targeted data or change the approach and test on new untouched games.

## 1. Define the target before collecting data

One screenshot is correct only if the predicted set of unit classes exactly equals the visible ground truth: no missing types and no extra types. Three correctly identified classes plus one invented class is a failure. This is multilabel **subset accuracy**, also called exact match ([scikit-learn definition](https://scikit-learn.org/stable/modules/generated/sklearn.metrics.accuracy_score.html)). Per-label accuracy and macro F1 are useful diagnostics, but neither is the 90% goal.

Initial supported scope:

- Classic graphics, normal camera height, unmodified unit models and the standard interface.
- The existing 48 unit types, with the existing merged alternate-form labels. Heroes, summons, buildings and corpses are not positive classes.
- Clearly identifiable living units in the battlefield crop. Define how partly occluded units are labeled before work starts. Put genuinely unidentifiable scenes in a separate challenge set; report their frequency rather than silently deleting hard but identifiable scenes.
- Start with native 16:9 captures. If support for 4:3 is required, collect and evaluate it as an explicit second category. Do not stretch a 4:3 screenshot and call it a native 16:9 test.
- Evaluate empty/hero-only/building-only scenes too: the correct result can be an empty set.

Completion target: **at least 450 of 500 independently held-out, representative real-game screenshots exactly correct**. Those screenshots must come from several entirely separate matches/replays. This is an observed 90% result on that test, not a guarantee for every future scene. Report results separately for ordinary play, crowded battles, empty scenes, and rare units. Do not achieve the headline by filling the test set with easy empty scenes.

## 2. Current evidence and decisions

| Evaluation | Result | What it means |
|---|---|---|
| Small Focus v2 on cleaned map4 | Macro F1 96.09%; exact match 79.29% | Good progress on generated scenes; not the real-game target |
| Ten external gameplay images, conservative partial visual labels | 10/20 confidently identified class occurrences detected; 14 clear false air detections in 6/10 images | Real-game transfer is weak; not a complete F1 or accuracy estimate |
| Same ten 4:3 images with aspect-preserving padding | Same 10/20 confirmed detections; false air detections increased from 14 to 19, affecting 7/10 images | Do not deploy padding as a fix based on this experiment |

The padding experiment changes border content as well as geometry. It does **not** measure performance on new native 16:9 gameplay. Raw outputs: `artifacts/gameplay-test/ten-images/proportions_comparison.json`. The current website preprocessing remains unchanged.

The site previously displayed its three nearest guesses when no class passed the threshold. That fallback has been removed so a screenshot can return no detections. This fixes a presentation problem, **not** the observed false predictions with scores above 90%. Those still need better training evidence and evaluation.

### Dedicated workstream: stop unsupported unit predictions

1. Freeze a real validation subset of ground-only scenes, hero/summon/building-only scenes, and scenes with genuine air units. Review it fully; partial labels are not enough for threshold selection.
2. Add hard negatives based on validation errors. A ground army with no Chimaeras must retain its true ground labels while omitting Chimaera. A hero-only scene should not force a hero into the closest ordinary unit class.
3. Measure false class additions per screenshot and the share of screenshots with any false addition, alongside missed classes and exact match. Require improvement on both real air and ground cases, not just fewer outputs.
4. Select thresholds on real validation data. Do not simply force a maximum of three predictions, filter by one race, or raise every threshold until almost nothing is returned: each can hide errors while increasing misses.
5. Review high-scoring false additions separately. A 99% model score is not proof that a unit exists. Use calibration/abstention only if validated; low confidence is not a reliable detector of every error.
6. If the classifier still relies on global scene patterns, try the object-detection pilot below. Showing boxes lets us inspect which pixels support each predicted unit. Boxes themselves are not proof: the detector must also pass real validation and final exact-match testing.

## 3. Collect a pilot before making thousands of images

Start with **200 real gameplay captures from at least 10 different matches/replays**, covering all four races. Use native 16:9, Classic graphics, and the same camera/UI assumptions as the capture maps. These are development/validation data, not the final test set.

Include quiet movement, workers at bases, small ground armies, genuine air units, mixed armies, battles with effects, and hero/summon/building-only negatives. Include ground-only scenes that resemble the scenes causing false Chimaera, Hippogryph Rider and Dragonhawk predictions.

Select varied moments; do not count adjacent near-identical video frames as independent examples. Preserve original resolution. Assign a stable match/replay ID at import. No screenshots or replays are currently available locally, so this collection step is still required. The ten downloaded diagnostic images remain outside training.

**Pilot gate:** labels are complete and reviewed; all four races and real air/ground contrasts are represented. If the current model still makes obvious air hallucinations on these native 16:9 scenes, data coverage and scene understanding remain the priority.

## 4. Add the proposed one-unit-type capture batch

Yes: this is a useful addition. Each image should contain **one class**, sometimes one instance and sometimes several instances of that same class. It teaches a clean visual association without ambiguity about other positive classes.

The existing JASS generator already randomizes facing, team color, animation and zoom. The new benefit is **systematic, balanced coverage of every type and form**, plus scenes that explicitly separate confusing classes.

For each unit type:

- Cover at least eight facings: 0°, 45°, 90°, 135°, 180°, 225°, 270° and 315°.
- Capture stand, walk and attack animations where that animation exists. Vary capture timing so all copies are not frozen at the same animation phase.
- Include the alternate models/forms already mapped to that label: druid forms, Troll variants and any other existing mappings. Audit the 51 model IDs against the 48-class vocabulary.
- Cycle **1, 2, 4 and 6 instances** per screenshot. A six-instance scene can show several facing angles together, but it is still only **one labeled training image**, not six independent examples for a whole-image classifier.
- Vary team colors, terrain, daylight, normal camera zoom and placement. Keep units visibly inside the crop; validate labels against what actually rendered.
- Start spaced apart, then add some same-type overlap. Avoid fixed rows and a fixed count of six in every image.

**Pilot budget:** 24–48 varied screenshots per class, approximately **1,152–2,304 screenshots**. These are proposed starting budgets, not sample counts known to produce 90%.

If systematic gaps remain, a full grid of 8 facings × 3 animation states × 2 scales × 3 background/light contexts is **144 screenshots/class**, or **6,912 for 48 classes**, before extra alternate forms. Do not generate the entire grid before checking that the pilot improves real-game validation.

**Gate:** inspect a sample from every class/form and every context. Exclude scenes where units are hidden, partly outside the input, still loading, or mislabeled. Keep capture runs/background groups separate across splits.

## 5. Teach difficult combinations and negatives

Add mixed scenes containing both sides of known confusions: ground armies versus actual air units, small workers versus infantry, and visually similar units. Use buildings, heroes, summons and effects as distractors without assigning them one of the 48 labels.

Both positive and negative examples matter. A ground-only scene must list its real ground classes while omitting air labels; a hero-only scene can correctly have no listed class. Do not train the model to suppress all flying classes indiscriminately.

A starting sampling experiment for training batches is 50% real gameplay, 20% difficult mixed generated scenes, 20% one-type scenes and 10% background/hero/building/summon-only negatives. This is a proposed sampling ratio, not a required number of files or a universal optimum. The old generated dataset can supply many of the mixed examples.

## 6. Label and split without leakage

Use `python game_capture/label_gameplay.py`. It opens a local Gradio interface and stores images and `labels.csv` under `data/gameplay/`. Choose every visible unit type; no model suggestions are preselected. Empty labels require explicit confirmation; uncertain screenshots can be excluded with a reason. The tool prevents one match ID from entering two splits and skips identical files already imported under another match.

It does not detect near-duplicates, prove that two different match IDs are different games, or verify human labels. Those still need review.

For the first substantial training round, aim for roughly **1,000–2,000 reviewed real training images**, **300–500 real validation images**, and a **500-image final real test set**, drawn from separate matches. Collect additional examples if rare classes or difficult scenes remain uncovered. These are planning estimates.

- Split by whole match/replay/capture run, never by random adjacent frames ([grouped splitting](https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.GroupShuffleSplit.html)).
- Review all validation/test labels twice. Audit a random portion of training labels and all suspicious failures.
- Track coverage per class. Keep a separate rare-unit challenge set so the overall score cannot hide failure on uncommon classes.
- The final test set stays untouched while selecting models, epochs, thresholds and preprocessing. Use validation failures for targeted collection.
- If test results are used to redesign the model, that set becomes development data; reserve new games for the next final test.

## 7. Retrain the current model first

Keep the current Small Focus checkpoint as a frozen baseline. Continue training with old and new data using the existing fastai workflow, rather than replacing the project with a configuration framework.

Run a small, recorded experiment sequence:

1. Frozen current checkpoint evaluated on the new real validation set.
2. Same architecture + one-type and difficult mixed captures.
3. Same architecture + the reviewed real gameplay data.
4. Only then compare another architecture using the same splits and label policy.

Start with a small learning rate, for example 1e-5–1e-4, and 3–5 epochs as an experiment. Save the best checkpoint according to real validation results; do not blindly run additional epochs when real validation has stopped improving. Report exact match, macro F1, per-class precision/recall, false additions and missed classes.

Select a global threshold on validation using exact match and check the precision/recall tradeoff. Consider per-class thresholds only after sufficient real validation support; 48 independently tuned thresholds on a tiny set can overfit. Never choose thresholds from the final test set.

Fastai supports the existing multilabel setup ([official tutorial](https://docs.fast.ai/tutorial.vision.html)).

## 8. Is a better model worth training?

**Yes, as a controlled comparison after the real-data baseline. A larger classifier is not the first fix.** The current Small model already generates confident wrong labels; a larger model can learn the same shortcuts from the same limited scenes. It also makes browser memory, download size and latency harder.

| Candidate | When to try it | Keep it only if |
|---|---|---|
| Current ConvNeXt Small + better data | First training experiment | Real validation improves over the frozen checkpoint |
| One larger classifier | Correct labels and coverage are good, but errors remain | It improves exact match enough to justify measured latency/memory cost |
| A small object detector, such as a YOLO-family detector | Small/overlapping units and whole-scene confusion remain the bottleneck | It improves the final screenshot-level class set, not just box metrics |

Object detection predicts locations and classes ([official task description](https://docs.ultralytics.com/tasks/detect)). It requires **bounding-box annotations for every visible in-scope unit**, not just the current screenshot-level labels ([dataset format](https://docs.ultralytics.com/datasets/detect)). Take the unique class names from the predicted boxes to preserve the website's current “which types are present?” output. Extra false boxes can still make a screenshot fail exact match.

Before boxing thousands of frames, annotate a small pilot of approximately 200–300 diverse frames and verify that this approach helps. If adopted, expand box coverage across all 48 classes and evaluate on the same kind of held-out games. Detection is a plausible better fit, not a guarantee of 90%.

## 9. Improve from measured failures

After each training round, review validation mistakes in groups: false air labels, missed workers, occlusion, small units, effects, alternate forms and unusual colors. Add new captures specifically for the largest error group. Compare the next checkpoint against the previous one on the unchanged validation split.

Do not keep increasing dataset size or architecture size without checking whether those particular failures improve. Do not remove identifiable hard cases merely to reach the number.

## 10. Final acceptance and website deployment

Freeze architecture, checkpoint, label order, input preparation and thresholds before the 500-image final test. The exact-match target is at least 450/500, with per-class and scene-category breakdowns. Ten images or 90% macro F1 are not substitutes.

Export the selected model, then re-evaluate the **exported model** on the same final test without changing anything based on those results. Report any conversion/quantization degradation. Validate actual browser predictions on a representative subset, including difficult battles and empty scenes, and measure loading time, warm inference time and memory on the intended computer.

Set a latency budget before selecting a larger deployment model; a proposed starting goal is a few seconds per screenshot on a normal desktop. Our current high-resolution Small browser test was much slower, so speed remains a separate engineering issue. A worker can keep the page responsive but does not automatically make inference faster. If the selected model cannot meet the browser budget, compare a smaller/distilled detector or a GPU-backed inference service before claiming the product is finished.

## Immediate next actions

1. Obtain new Classic 16:9 gameplay captures/replays; none are currently supplied.
2. Label the 200-image real pilot with the local tool and establish whole-match splits.
3. Prepare a balanced one-unit-type capture run, including the proposed six-instance scenes and alternate forms.
4. Evaluate the frozen current model on the new real validation data.
5. Train the controlled data-improvement experiments, then decide whether a larger classifier or detection pilot is worthwhile.

There is currently **no newly trained checkpoint and no verified 90% real-game result**. The existing model remains deployed until a candidate passes the evidence gates above.
