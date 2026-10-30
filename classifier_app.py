import ast
from collections import Counter
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import gradio as gr, numpy as np, onnxruntime as ort, pandas as pd

CONF, OVERLAP = 0.5, 0.7        # conf was picked on validation; 0.7 = the YOLO default for removing duplicates
session = ort.InferenceSession('best.onnx')      # exported by warcraft3_detector.ipynb
labels = ast.literal_eval(session.get_modelmeta().custom_metadata_map['names'])
font = ImageFont.load_default(size=20)

def hide_worker_icon(img):
    "Same as in warcraft3_detector.ipynb: the idle-worker portrait hints at worker classes."
    img = img.copy()
    img.paste((0, 0, 0), (160, 465, 220, 525))
    return img

def iou(a, b):
    w = max(0, min(a[2], b[2]) - max(a[0], b[0]))
    h = max(0, min(a[3], b[3]) - max(a[1], b[1]))
    return w * h / ((a[2]-a[0]) * (a[3]-a[1]) + (b[2]-b[0]) * (b[3]-b[1]) - w * h)

def predict(img):
    "The raw answer for 33600 places on the screenshot: a box and a score for each of the 48 units."
    top = (1280 - img.height) // 2
    square = Image.new('RGB', (1280, 1280), (114, 114, 114))      # the model takes a square image
    square.paste(hide_worker_icon(img), (0, top))
    pixels = (np.asarray(square, dtype=np.float32) / 255).transpose(2, 0, 1)[None]
    out = session.run(None, {'images': pixels})[0][0].T           # rows: centre x, y, width, height, 48 scores
    x, y, w, h = out[:, 0], out[:, 1] - top, out[:, 2], out[:, 3]
    return np.stack([x - w/2, y - h/2, x + w/2, y + h/2], axis=1), out[:, 4:]

def classify(img, conf=CONF):
    "One (box, top 3 guesses) per unit. Several places fire for one unit, so we keep only the strongest of them."
    boxes, scores = predict(img)
    units, names = [], []
    for i in np.argsort(-scores.max(axis=1)):
        k = scores[i].argmax()
        if scores[i, k] < conf: break
        if all(k != name or iou(boxes[i], u[0]) < OVERLAP for u, name in zip(units, names)):
            top3 = np.argsort(-scores[i])[:3]
            units.append((boxes[i], [(labels[int(c)], float(scores[i, c])) for c in top3]))
            names.append(k)
    return units

def resize(img):
    return img.convert('RGB').resize((1280, round(1280 * img.height / img.width)))

def show(img, conf):
    img = resize(img)
    units = classify(img, conf)
    marked = img.copy()
    draw = ImageDraw.Draw(marked)
    crops, table, types = [], [], {}
    for n, (box, guesses) in enumerate(units, 1):
        x, y = (box[0] + box[2]) / 2, box[3] - (box[3] - box[1]) * 145 / 465      # where the unit stands
        draw.ellipse((x - 5, y - 5, x + 5, y + 5), fill=(255, 230, 0))
        draw.text((x + 8, y - 12), str(n), fill=(255, 230, 0), font=font, stroke_width=3, stroke_fill=(0, 0, 0))
        name, score = guesses[0]
        crops.append((img.crop(tuple(int(v) for v in box)), f'{n}. {name} {score:.0%}'))
        table.append([n] + [f'{g} {s:.1%}' for g, s in guesses])
        types[name] = max(types.get(name, 0), score)
    counts = Counter(g[0][0] for _, g in units)
    return {f'{counts[name]} × {name}': score for name, score in types.items()}, marked, crops, table

if __name__ == '__main__':
    image = gr.Image(type='pil', sources=['upload', 'clipboard'], label='Screenshot')
    conf = gr.Slider(0.1, 0.9, value=CONF, step=0.05, label='Confidence (0.5 was picked on validation)')
    outputs = [gr.Label(num_top_classes=12, label='Units on this screenshot'),
               gr.Image(label='Numbered units'),
               gr.Gallery(label='Each unit', columns=4, height=340, object_fit='contain'),
               gr.Dataframe(headers=['#', 'Best guess', '2nd guess', '3rd guess'], label='Top 3 guesses for each unit')]
    good = pd.read_csv('good_screenshots_70.csv')['fname'][::14]
    intf = gr.Interface(fn=show, inputs=[image, conf], outputs=outputs, flagging_mode='never',
                        examples=[[str(Path('data/screens')/f), CONF] for f in good],
                        title='Warcraft III Unit Classifier',
                        description='Drop in or paste a Warcraft III screenshot (Classic graphics, 16:9). '
                                    'For every unit the model gives a name, its confidence and its next two guesses.')
    intf.launch()
