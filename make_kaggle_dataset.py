"""Pack everything the Version 3 notebooks need into kaggle_dataset.zip (upload it as a private Kaggle dataset).

python make_kaggle_dataset.py
"""
import zipfile
from pathlib import Path
import pandas as pd

files = [Path('data/single_units/labels.csv'), Path('data/single_units/excluded.csv')]
files += sorted(Path('data/single_units/screens').glob('*.jpg'))

for csv_name in ['units.csv', 'battle_units.csv']:        # mixed scenes and computer-vs-computer games
    if Path('data', csv_name).is_file():
        files += [Path('data', csv_name)]
        files += [Path('data/screens')/f for f in pd.read_csv(Path('data', csv_name))['fname'].unique()]
if Path('data/labels.csv').is_file():                      # Version 2 validation map, to compare with
    files += [Path('data/labels.csv')]
    files += sorted(Path('data/screens').glob('map4_*.jpg'))

for split in ['train', 'test']:                            # real screenshots, only the checked labels
    folder = Path('my_screenshots')/split
    for txt in sorted((folder/'labels').glob('*.txt')):
        files.append(txt)
        files += [p for p in folder.glob(txt.stem + '.*') if p.suffix.lower() in ('.png', '.jpg', '.jpeg')]

files = sorted(set(files))
with zipfile.ZipFile('kaggle_dataset.zip', 'w', zipfile.ZIP_STORED) as z:   # jpg/png are already compressed
    for f in files: z.write(f, f.as_posix())
print(len(files), 'files ->', 'kaggle_dataset.zip', round(Path('kaggle_dataset.zip').stat().st_size / 1e9, 2), 'GB')
