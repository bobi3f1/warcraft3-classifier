from collections import Counter
from pathlib import Path
from PIL import ImageDraw, ImageFont
from ultralytics import YOLO
import gradio as gr

model = YOLO('best.onnx', task='detect')      # exported by warcraft3_detector.ipynb
font = ImageFont.load_default(size=15)

def hide_worker_icon(img):
    "Same as in warcraft3_detector.ipynb: the idle-worker portrait hints at worker classes."
    img = img.copy()
    img.paste((0, 0, 0), (160, 465, 220, 525))
    return img

def find_units(img, conf):
    img = img.convert('RGB').resize((1280, round(1280 * img.height / img.width)))
    result = model.predict(hide_worker_icon(img), imgsz=1280, conf=conf, verbose=False, device='cpu')[0]
    names = [result.names[int(c)] for c in result.boxes.cls.tolist()]
    draw = ImageDraw.Draw(img)
    for box, name, score in zip(result.boxes.xyxy.tolist(), names, result.boxes.conf.tolist()):
        left, top, right, bottom = box
        x, y = (left + right) / 2, bottom - (bottom - top) * 145 / 465     # where the unit stands (the box is loose)
        draw.rectangle(box, outline=(255, 230, 0), width=1)
        draw.ellipse((x - 4, y - 4, x + 4, y + 4), fill=(255, 230, 0))
        draw.text((x + 7, y - 9), f'{name} {score:.2f}', fill=(255, 230, 0), font=font,
                  stroke_width=2, stroke_fill=(0, 0, 0))
    counts = [f'{n} × {name}' for name, n in Counter(names).most_common()]
    return img, '\n'.join([f'Units found: {len(names)}'] + counts)

image = gr.Image(type='pil', sources=['upload', 'clipboard'], label='Screenshot')
conf = gr.Slider(0.1, 0.9, value=0.5, step=0.05, label='Confidence (0.5 was picked on validation)')
found_image = gr.Image(label='Found units')
found_list = gr.Textbox(label='Units', lines=10)
screens = Path('data/screens')
examples = sorted(screens.glob('battle-test1_*.jpg'))[::50] + sorted(screens.glob('mixed-test1-*.jpg'))[::100]

intf = gr.Interface(fn=find_units, inputs=[image, conf], outputs=[found_image, found_list],
                    examples=[[str(f), 0.5] for f in examples], flagging_mode='never',
                    title='Warcraft III Unit Detector',
                    description='Drop in or paste a Warcraft III screenshot (Classic graphics, 16:9). '
                                'The example screenshots come from maps the model never trained on.')
intf.launch()
