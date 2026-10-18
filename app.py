from fastai.vision.all import *
import gradio as gr

def crop_ui(img: PILImage):
    "Version 2's model.pkl needs this function (same as in warcraft3_screenshots.ipynb)"
    w, h = img.size
    return img.crop((0, int(h * 30 / 720), w, int(h * 530 / 720)))

learn = load_learner('model.pkl')
categories = learn.dls.vocab

def classify_image(img):
    pred, idx, probs = learn.predict(img)
    return dict(zip(categories, map(float, probs)))

image = gr.Image(type='pil')
label = gr.Label(num_top_classes=3)
examples = sorted(str(f) for f in Path('examples').glob('*.jpg'))

intf = gr.Interface(fn=classify_image, inputs=image, outputs=label, examples=examples,
                    title='Warcraft III Unit Classifier',
                    description='Upload a picture of one Warcraft III unit (Human, Orc, Night Elf or Undead).')
intf.launch()   # intf.launch(share=True) gives a temporary public link while this runs
