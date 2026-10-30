"""Capture one unit class per screenshot from dataset_trigger_single.j."""
import argparse
import csv
from datetime import datetime
import os
from pathlib import Path
import re
import sys
import time


def parse_marker(text, known_labels):
    values = re.findall(r'Preload\( "([^"]*)" \)', text)
    labels = [v for v in values if not v.startswith('META|')]
    metadata = [v.split('|')[1:] for v in values if v.startswith('META|')]
    if len(labels) != 1 or labels[0] not in known_labels:
        raise ValueError('Expected exactly one known unit class')
    if len(metadata) != 1 or len(metadata[0]) != 7:
        raise ValueError('Missing single-class scene metadata; check the map trigger')
    c, round_id, copies, facing, position, zoom, variant = metadata[0]
    if not (0 <= int(c) < 48 and 0 <= int(round_id) < 32 and 1 <= int(copies) <= 3
            and 0 <= int(position) < 9 and 1500 <= float(zoom) <= 1800
            and 0 <= int(variant) < 51):
        raise ValueError('Scene metadata is out of range')
    return labels[0], [c, round_id, copies, facing, position, zoom, variant]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--map', required=True, help='unique map name; use different maps for train/valid/test')
    parser.add_argument('--split', required=True, choices=['trial', 'train', 'valid', 'test'])
    parser.add_argument('--shots', type=int, default=1536)
    parser.add_argument('--monitor', type=int, default=1)
    parser.add_argument('--minutes', type=float, help='stop this many minutes after the first scene arrives')
    parser.add_argument('--wc3-data', type=Path,
                        default=Path.home()/'Documents'/'Warcraft III'/'CustomMapData')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9-]+', args.map):
        parser.error('--map must contain only letters, numbers and hyphens')
    if not 1 <= args.shots <= 1536:
        parser.error('--shots must be between 1 and 1536')
    if args.monitor < 1:
        parser.error('--monitor must be positive')
    if args.minutes is not None and not 0 < args.minutes <= 180:
        parser.error('--minutes must be greater than 0 and at most 180')
    root = Path(__file__).resolve().parents[1]
    output = root/'data/single_units'
    labels_csv = output/'labels.csv'
    markers = args.wc3_data/'wc3single'
    if labels_csv.exists():
        with labels_csv.open(encoding='utf-8', newline='') as f:
            for row in csv.DictReader(f):
                if row['map'] == args.map and row['split'] != args.split and row['split'] != 'trial' and args.split != 'trial':
                    parser.error('This map already belongs to another split. Use a different map.')
    print('Markers:', markers)
    print('Screenshots:', output/'screens')
    print('Labels:', labels_csv)
    print('Map:', args.map, 'Split:', args.split, 'Scene slots:', args.shots)
    if args.check:
        return
    try:
        import mss
        import numpy as np
        from PIL import Image
    except ModuleNotFoundError:
        python = root/'.venv/Scripts/python.exe'
        if python.is_file() and Path(sys.executable).resolve() != python.resolve():
            os.execv(str(python), [str(python), str(Path(__file__).resolve()), *sys.argv[1:]])
        parser.exit(1, 'Install requirements.txt in the project .venv.\n')

    trigger = (root/'game_capture/dataset_trigger_single.j').read_text()
    known = set(re.findall(r'set name\[\d+\] = "([^"]+)"', trigger))
    assert len(known) == 48
    markers.mkdir(parents=True, exist_ok=True)
    for path in markers.glob('shot_*.txt'):
        if re.fullmatch(r'shot_\d+\.txt', path.name):
            path.unlink()  # Only temporary markers in this generator's directory.
    (output/'screens').mkdir(parents=True, exist_ok=True)
    session = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    columns = ['fname','labels','map','split','session','shot','class_index','round',
               'copies','facing','position','zoom','variant']
    saved = 0
    previous = None
    deadline = None
    print('Now start a NEW Test Map game. Keep Warcraft visible. Ctrl+C stops safely.', flush=True)
    with mss.MSS() as screen, labels_csv.open('a', newline='', encoding='utf-8') as f:
        if args.monitor >= len(screen.monitors):
            parser.error('Selected monitor does not exist')
        writer = csv.writer(f)
        if f.tell() == 0:
            writer.writerow(columns)
        for shot in range(args.shots):
            marker = markers/f'shot_{shot}.txt'
            started = time.monotonic()
            while not marker.exists():
                if deadline is not None and time.monotonic() >= deadline:
                    print(f'Time limit reached: {saved} screenshots saved.', flush=True)
                    return
                timeout = 600 if shot == 0 else 120
                if time.monotonic() - started > timeout:
                    print(f'Stopped: no {marker.name}. {saved} screenshots kept. Check Test Map and an open capture area.', flush=True)
                    return
                time.sleep(0.05)
            if deadline is None and args.minutes is not None:
                deadline = time.monotonic() + args.minutes * 60
            if deadline is not None and time.monotonic() >= deadline:
                print(f'Time limit reached: {saved} screenshots saved.', flush=True)
                return
            label, metadata = parse_marker(marker.read_text(errors='ignore'), known)
            if int(metadata[0]) != shot % 48 or int(metadata[1]) != shot // 48:
                raise ValueError(f'{marker.name}: scene sequence mismatch')
            if (markers/f'shot_{shot+1}.txt').exists():
                print(shot, 'skipped: scene already advanced', flush=True)
                continue
            grab = screen.grab(screen.monitors[args.monitor])
            img = Image.frombytes('RGB', grab.size, grab.rgb).resize((1280,720))
            pixels = np.asarray(img, dtype=np.float32)[30:530]
            if previous is not None and np.abs(pixels-previous).mean() < 0.5:
                print(shot, 'skipped: unchanged battlefield', flush=True)
                continue
            if (markers/f'shot_{shot+1}.txt').exists():
                print(shot, 'skipped: scene advanced during capture', flush=True)
                continue
            fname = f'single_{args.map}_{session}_{shot:04d}.jpg'
            with (output/'screens'/fname).open('xb') as target:
                img.save(target, format='JPEG', quality=95)
            writer.writerow([fname,label,args.map,args.split,session,shot,*metadata])
            f.flush()
            previous = pixels
            saved += 1
            print(f'{saved}: {fname} | {label} | copies={metadata[2]}', flush=True)
    print(f'Done: {saved}/{args.shots} saved. Review screenshots before training.')


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print('\nStopped; captured images and labels are kept.')
