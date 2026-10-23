"""Draft boxes for real game screenshots, so you only have to fix them instead of drawing every box.

1. Put screenshots from real games in my_screenshots/train/ and my_screenshots/test/ (Classic graphics).
2. python prelabel_screenshots.py
3. Fix the drafts in a labeling tool (README "Истински screenshot-и") and save them in labels/ next to the images.
The notebooks use only labels/, never labels_draft/.
"""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image
from ultralytics import YOLO
from fastai.vision.all import load_learner, PILImage

parser = argparse.ArgumentParser()
parser.add_argument('--folder', default='my_screenshots')
parser.add_argument('--detector', default='models/detector/weights/best.pt')
parser.add_argument('--classifier', default='data/unit_crops/unit_classifier.pkl')
parser.add_argument('--conf', type=float, default=0.3)
args = parser.parse_args()

if __name__ == '__main__':
    detector, classifier = YOLO(args.detector), load_learner(args.classifier)
    vocab = list(classifier.dls.vocab)
    root = Path(args.folder)
    (root/'classes.txt').write_text('\n'.join(vocab) + '\n')    # line number = class number in the .txt files

    for split in ['train', 'test']:
        images = [p for p in sorted((root/split).glob('*')) if p.suffix.lower() in ('.png', '.jpg', '.jpeg')]
        (root/split/'labels_draft').mkdir(parents=True, exist_ok=True)
        for path in images:
            img = Image.open(path).convert('RGB')
            small = img.resize((1280, round(1280 * img.height / img.width)))
            small.paste((0, 0, 0), (160, 465, 220, 525))           # hide the idle-worker icon, as in training
            boxes = detector.predict(small, imgsz=1280, conf=args.conf, verbose=False)[0].boxes.xyxyn.tolist()
            lines = []
            if boxes:
                w, h = img.size
                crops = [PILImage.create(np.array(img.crop((round(l*w), round(t*h), round(r*w), round(b*h)))))
                         for l, t, r, b in boxes]
                with classifier.no_bar(): probs, _ = classifier.get_preds(dl=classifier.dls.test_dl(crops))
                for (l, t, r, b), k in zip(boxes, probs.argmax(1).tolist()):
                    lines.append(f'{k} {(l+r)/2:.5f} {(t+b)/2:.5f} {r-l:.5f} {b-t:.5f}')
            (root/split/'labels_draft'/f'{path.stem}.txt').write_text('\n'.join(lines))
            print(split, path.name, len(lines), 'units:', sorted(vocab[int(l.split()[0])] for l in lines), flush=True)
    print('Done. Drafts are in labels_draft/; save the checked ones in labels/.')
