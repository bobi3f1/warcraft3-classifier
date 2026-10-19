"""Label local Classic gameplay screenshots: python game_capture/label_gameplay.py."""
import csv
import hashlib
import json
import re
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT/'data'/'gameplay'
LABELS = json.loads((ROOT/'docs'/'model.json').read_text(encoding='utf-8'))['labels']
FIELDS = ['fname', 'original_fname', 'labels', 'match_id', 'split', 'status', 'note', 'sha256']


def read_rows():
    path = DATA/'labels.csv'
    if not path.exists():
        return []
    with path.open(newline='', encoding='utf-8') as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames != FIELDS:
            raise ValueError('Unexpected labels.csv columns; keep the original file for recovery.')
        return list(reader)


def write_rows(rows):
    DATA.mkdir(parents=True, exist_ok=True)
    path = DATA/'labels.csv'
    temporary = DATA/'labels.csv.tmp'
    with temporary.open('w', newline='', encoding='utf-8') as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    temporary.replace(path)


def import_files(files, match_id, split):
    match_id = (match_id or '').strip()
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', match_id):
        raise ValueError('Enter a match/replay name using letters, numbers, _ or -.')
    if split not in ['train', 'validation', 'test']:
        raise ValueError('Choose train, validation or test.')
    if not files:
        raise ValueError('Choose screenshots from one match first.')
    rows = read_rows()
    if any(row['match_id'] == match_id and row['split'] != split for row in rows):
        raise ValueError('This match already belongs to another split. Keep the whole match in one split.')
    known = {row['sha256'] for row in rows}
    additions = []
    for file in files:
        source = Path(file)
        if source.suffix.lower() not in ['.jpg', '.jpeg', '.png', '.bmp', '.tga']:
            raise ValueError(f'Unsupported screenshot type: {source.name}')
        with Image.open(source) as image:
            image.verify()
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if digest in known:
            continue
        known.add(digest)
        name = f'{match_id}_{digest[:20]}{source.suffix.lower()}'
        additions.append((source, dict(fname=name, original_fname=source.name, labels='',
                         match_id=match_id, split=split, status='unreviewed', note='', sha256=digest)))
    (DATA/'screens').mkdir(parents=True, exist_ok=True)
    for source, row in additions:
        shutil.copy2(source, DATA/'screens'/row['fname'])
        rows.append(row)
    write_rows(rows)
    return f'Imported {len(additions)}; skipped {len(files)-len(additions)} identical files. Nothing was labeled automatically.'


def save_review(fname, labels, no_units=False, exclude=False, note=''):
    rows = read_rows()
    row = next((row for row in rows if row['fname'] == fname), None)
    if row is None:
        raise ValueError('Select a screenshot first.')
    labels = sorted(set(labels or []))
    if not set(labels) <= set(LABELS):
        raise ValueError('Unknown unit label.')
    if exclude:
        if not note.strip():
            raise ValueError('Add a short reason before excluding an uncertain screenshot.')
        row.update(labels='', status='excluded', note=note.strip())
    else:
        if bool(labels) == bool(no_units):
            raise ValueError('Select the visible unit types OR confirm that no listed units are visible.')
        row.update(labels=';'.join(labels), status='reviewed', note=note.strip())
    write_rows(rows)
    return row['status']


def build_app():
    import gradio as gr

    def refresh(message=''):
        rows = read_rows()
        pending = next((r['fname'] for r in rows if r['status'] == 'unreviewed'), None)
        counts = {status: sum(r['status'] == status for r in rows)
                  for status in ['unreviewed', 'reviewed', 'excluded']}
        return gr.update(choices=[r['fname'] for r in rows], value=pending), f'{message}\n{counts}'

    def show(fname):
        row = next((r for r in read_rows() if r['fname'] == fname), None)
        if row is None:
            return None, [], False, '', 'Choose a screenshot, or import a match above.'
        with Image.open(DATA/'screens'/fname) as source:
            image = source.convert('RGB')
        labels = row['labels'].split(';') if row['labels'] else []
        metadata = f"{row['original_fname']} · match {row['match_id']} · {row['split']} · {row['status']} · {image.width}×{image.height}"
        return image, labels, row['status'] == 'reviewed' and not labels, row['note'], metadata

    def add(files, match_id, split):
        return refresh(import_files(files, match_id, split))

    def save(fname, labels, no_units, note):
        save_review(fname, labels, no_units=no_units, note=note)
        return refresh('Labels saved.')

    def exclude(fname, note):
        save_review(fname, [], exclude=True, note=note)
        return refresh('Excluded from training and evaluation.')

    with gr.Blocks(title='Warcraft III gameplay labels') as app:
        gr.Markdown('# Label real Warcraft III gameplay\nFiles and labels stay on this computer. Use Classic graphics. Import **one match/replay at a time**. Keep whole matches in one split. Use several separate matches for each split.')
        with gr.Row():
            uploads = gr.File(label='Screenshots from one match', file_count='multiple',
                              file_types=['.jpg', '.jpeg', '.png', '.bmp', '.tga'], type='filepath')
            with gr.Column():
                match = gr.Textbox(label='Match/replay ID', placeholder='match_001')
                split = gr.Dropdown(['train', 'validation', 'test'], value='train', label='Use this entire match for')
                add_button = gr.Button('Import screenshots')
        status = gr.Textbox(label='Queue', interactive=False)
        current = gr.Dropdown(label='Screenshot (reviewed files can also be corrected)')
        metadata = gr.Textbox(label='Current image', interactive=False)
        image = gr.Image(label='Full screenshot — inspect the battlefield, not portraits or unit icons', interactive=False)
        labels = gr.CheckboxGroup(choices=LABELS, label='Every visible unit TYPE from the list; do not count units')
        no_units = gr.Checkbox(label='I checked: no listed unit types are visible (heroes/buildings/summons may still be present)')
        note = gr.Textbox(label='Note / reason for exclusion')
        gr.Markdown('If any class is too obscured to label confidently, exclude the screenshot. Do not guess. Ignore heroes, buildings, summons, corpses, UI portraits and icons. No model suggestions are preselected.')
        with gr.Row():
            save_button = gr.Button('Save labels and next', variant='primary')
            exclude_button = gr.Button('Exclude uncertain image and next')
        outputs = [image, labels, no_units, note, metadata]
        current.input(show, inputs=current, outputs=outputs)
        add_button.click(add, [uploads, match, split], [current, status]).then(show, current, outputs)
        save_button.click(save, [current, labels, no_units, note], [current, status]).then(show, current, outputs)
        exclude_button.click(exclude, [current, note], [current, status]).then(show, current, outputs)
        app.load(refresh, outputs=[current, status]).then(show, current, outputs)
    return app


if __name__ == '__main__':
    build_app().queue(default_concurrency_limit=1).launch(server_name='127.0.0.1', share=False, show_error=True)
