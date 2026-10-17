"""Save a screenshot + labels every time the dataset map shows a new scene.

1. Start this:  python game_capture/capture.py --map twisted_meadows --shots 800
2. Start the map in Warcraft III (World Editor -> Test Map) and don't touch the mouse.
Screenshots go to data/screens/, labels to data/labels.csv. Stop any time with Ctrl+C.
"""
import argparse, csv, re, time
from pathlib import Path
import mss
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('--map', required=True, help='short name of the map, e.g. twisted_meadows')
parser.add_argument('--shots', type=int, default=800)
parser.add_argument('--wc3-data', default=Path.home()/'Documents'/'Warcraft III'/'CustomMapData',
                    help='folder where the map writes its files')
args = parser.parse_args()

shots_dir = Path(args.wc3_data)/'wc3dataset'
shots_dir.mkdir(parents=True, exist_ok=True)
for old in shots_dir.glob('shot_*.txt'): old.unlink()   # files from an earlier game

out = Path('data/screens')
out.mkdir(parents=True, exist_ok=True)
labels_csv = Path('data/labels.csv')
new_csv = not labels_csv.exists()

print(f'Waiting for the game... (files appear in {shots_dir})', flush=True)
while not list(shots_dir.glob('shot_*.txt')): time.sleep(0.1)
first = min(int(p.stem.split('_')[1]) for p in shots_dir.glob('shot_*.txt'))

with mss.MSS() as screen, labels_csv.open('a', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    if new_csv: writer.writerow(['fname', 'labels'])
    for i in range(first, first + args.shots):
        shot = shots_dir/f'shot_{i}.txt'
        while not shot.exists(): time.sleep(0.05)
        time.sleep(0.4)                                   # let the game draw the new scene
        grab = screen.grab(screen.monitors[1])            # the main monitor
        img = Image.frombytes('RGB', grab.size, grab.rgb).resize((1280, 720))
        if (shots_dir/f'shot_{i + 1}.txt').exists():
            print(f'shot {i}: too slow, scene already changed - skipped')
            continue
        units = sorted(set(re.findall(r'Preload\( "([^"]*)" \)', shot.read_text(errors='ignore'))))
        fname = f'{args.map}_{i:04d}.jpg'
        img.save(out/fname, quality=90)
        writer.writerow([fname, ';'.join(units)])
        f.flush()
        print(i, fname, units, flush=True)
print('Done.')
