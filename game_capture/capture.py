"""Save a screenshot + labels every time the dataset map shows a new scene.

1. Start this:  python game_capture/capture.py --map twisted_meadows --shots 800
2. Start the map in Warcraft III (World Editor -> Test Map) and don't touch the mouse.
Screenshots go to data/screens/, labels to data/labels.csv, and every unit with its position
(relative to the camera target, for the detector boxes) to data/units.csv. Stop any time with Ctrl+C.
"""
import argparse, csv, re, time
from pathlib import Path
import mss
import numpy as np
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('--map', required=True, help='short name of the map, e.g. twisted_meadows')
parser.add_argument('--shots', type=int, default=800)
parser.add_argument('--wc3-data', default=Path.home()/'Documents'/'Warcraft III'/'CustomMapData',
                    help='folder where the map writes its files')
parser.add_argument('--units-csv', default='data/units.csv',
                    help='data/battle_units.csv for dataset_trigger_battle.j')
args = parser.parse_args()

shots_dir = Path(args.wc3_data)/'wc3dataset'
shots_dir.mkdir(parents=True, exist_ok=True)
for old in shots_dir.glob('shot_*.txt'): old.unlink()   # files from an earlier game

out = Path('data/screens')
out.mkdir(parents=True, exist_ok=True)
labels_csv = Path('data/labels.csv')
new_csv = not labels_csv.exists()
units_csv = Path(args.units_csv)
new_units_csv = not units_csv.exists()
# z = height of the unit's ground above the ground under the camera (0 if the map doesn't write it);
# a file started before z existed keeps its 5 columns
columns = ['fname', 'label', 'x', 'y', 'zoom', 'z']
if not new_units_csv: columns = units_csv.read_text(encoding='utf-8').split('\n', 1)[0].strip().split(',')

print(f'Waiting for the game... (files appear in {shots_dir})', flush=True)
while not list(shots_dir.glob('shot_*.txt')): time.sleep(0.1)
first = min(int(p.stem.split('_')[1]) for p in shots_dir.glob('shot_*.txt'))
prev = None                                               # pixels of the last saved screenshot

with mss.MSS() as screen, labels_csv.open('a', newline='', encoding='utf-8') as f, \
     units_csv.open('a', newline='', encoding='utf-8') as fu:
    writer, unit_writer = csv.writer(f), csv.writer(fu)
    if new_csv: writer.writerow(['fname', 'labels'])
    if new_units_csv: unit_writer.writerow(columns)
    for i in range(first, first + args.shots):
        shot = shots_dir/f'shot_{i}.txt'
        while not shot.exists(): time.sleep(0.05)
        time.sleep(0.4)                                   # let the game draw the new scene
        for attempt in range(10):                         # the game freezes for a moment when it loads a new model
            grab = screen.grab(screen.monitors[1])        # the main monitor
            img = Image.frombytes('RGB', grab.size, grab.rgb).resize((1280, 720))
            pixels = np.asarray(img, dtype=np.float32)[40:520]   # the map area, without the UI
            if prev is None or np.abs(pixels - prev).mean() > 3: break
            time.sleep(0.2)                               # still the old scene on screen - try again
        else:
            print(f'shot {i}: screen did not change - skipped')
            continue
        prev = pixels
        if (shots_dir/f'shot_{i + 1}.txt').exists():
            print(f'shot {i}: too slow, scene already changed - skipped')
            continue
        lines = re.findall(r'Preload\( "UNIT\|([^"]*)" \)', shot.read_text(errors='ignore'))
        placed = [line.split('|') for line in lines]          # [name, x, y, zoom, (z)] for every unit
        units = sorted(set(p[0] for p in placed))
        fname = f'{args.map}_{i:04d}.jpg'
        img.save(out/fname, quality=90)
        writer.writerow([fname, ';'.join(units)])
        for p in placed: unit_writer.writerow(([fname] + p + ['0'])[:len(columns)])
        f.flush(); fu.flush()
        print(i, fname, units, flush=True)
print('Done.')
