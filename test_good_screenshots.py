"""Score classifier_app.py on the 70 good screenshots of the unseen test map.
Good = no unit stacked on another, none cut off, none covered by a spell effect or a building.
The list was fixed before the model's answers on them were looked at.
"""
from collections import Counter
from pathlib import Path
from PIL import Image
import pandas as pd
from classifier_app import classify, resize

good = pd.read_csv('good_screenshots_70.csv')
exact, names_right, count_right, units_right, units_total = 0, 0, 0, 0, 0
wrong = []
for r in good.itertuples():
    true = sorted(r.units.split(';'))
    guess = sorted(g[0][0] for _, g in classify(resize(Image.open(Path('data/screens')/r.fname))))
    exact += guess == true
    names_right += set(guess) == set(true)
    count_right += len(guess) == len(true)
    units_right += sum((Counter(guess) & Counter(true)).values())
    units_total += len(true)
    if guess != true:
        wrong.append((r.fname, list((Counter(true) - Counter(guess)).elements()), list((Counter(guess) - Counter(true)).elements())))

n = len(good)
print(f'{n} screenshots, {units_total} units')
print(f'fully correct (same units, same number of each): {exact}/{n} = {exact / n:.1%}')
print(f'right names, count ignored: {names_right / n:.1%}')
print(f'right number of units: {count_right / n:.1%}')
print(f'units named right: {units_right}/{units_total} = {units_right / units_total:.1%}')
for fname, missed, extra in wrong:
    print(fname, 'missed', missed, 'extra', extra)
