# Warcraft III — класификатор на единици

Учебен проект по курса [Practical Deep Learning for Coders](https://course.fast.ai/) (Jeremy Howard):
**Lesson 1** ("Is it a bird?"), **Lesson 2** (почистване на данни, публикуване в интернет),
**Lesson 3** (избор на модел) и **fastbook глава 6** (multi-label класификация).

Проектът има две версии:

| | Версия 1 (готова) | Версия 2 (основната) |
|---|---|---|
| Notebook | `warcraft3_classifier.ipynb` | `warcraft3_screenshots.ipynb` |
| Вход | снимка на **една** единица | **цял screenshot** от играта |
| Изход | коя е единицата (8 вида) | кои единици има на снимката (48 вида) |
| Данни | снимки от интернет, почистени ръчно | screenshot-и от самата игра (класическа графика) |
| Тип | single-label (softmax) | multi-label (sigmoid) |

## Резултати от версия 1

| Опит | error_rate (validation) |
|---|---|
| `resnet18`, всички свалени снимки (неизчистени) | 52% |
| `resnet18`, след ръчно почистване на данните | 26% |
| `resnet34`, изчистени данни | 21% |
| **`convnext_tiny_in22k`, изчистени данни** | **14–18%** (финален модел: 17.9%, т.е. ~82% познати) |
| същият модел, смален за браузъра (int8 ONNX) | 19.0% (~81% познати) |

Изводът: **почистването на данните помогна повече от смяната на модела.** Снимките от интернет са
пълни с fan art, Reforged графика и грешни картинки — затова версия 2 използва снимки от самата игра.

## Резултати от версия 2

Данни: 3161 screenshot-а от 4 карти (Lordaeron Summer ×2, Northrend, Ashenvale). Проверката (validation) е
върху **цяла карта (map4), която моделът никога не е виждал** — 796 снимки с 2742 единици.

| Опит | F1 (macro) | намерени единици | грешни "намерени" |
|---|---|---|---|
| `convnext_tiny_in22k`, цял екран 640×360, 6 епохи | 0.38 | 44% | 2046 |
| **същият, изрязан интерфейс → 768×300, 12 епохи** | **0.64** | **65%** | **900** |
| същият, смален за браузъра (int8 ONNX) | 0.64 | 64% | 902 |

- Прагът (threshold) е 0.2, избран по F1 върху validation.
- Големите единици се познават добре (Obsidian Statue, Mountain Giant, Siege Engine, Kodo — над 90%),
  малките пешеходци — зле (Ghoul 22%, Peon 24%, Grunt 29%, Peasant 31%): на 768×300 те са 15–25 пиксела.
- Само 18% от снимките са познати **изцяло** (всички единици, без грешна).
- Опит с learning rate от `lr_find` директно — обучението се разпадна (тегла `NaN`); затова 2e-3 и
  `SaveModelCallback` + `TerminateOnNaNCallback` (подробности в notebook-а).

## Файлове

| Файл | Какво прави |
|---|---|
| `warcraft3_screenshots.ipynb` | Версия 2: обучение на multi-label модел върху screenshot-и + export за сайта |
| `warcraft3_classifier.ipynb` | Версия 1 (обучена): сваляне от интернет → почистване → обучение → export |
| `game_capture/dataset_trigger.j` | Скрипт за World Editor: показва случайни единици и записва кои са |
| `game_capture/capture.py` | Прави screenshot-ите и записва етикетите в `data/labels.csv` |
| `docs/` | **Сайтът** за GitHub Pages: `index.html`, `model.onnx`, `model.json`, примерни снимки |
| `app.py` | Gradio приложение (като в Lesson 2) — за пускане на собствения компютър |
| `data/` | Снимките (не се качват в GitHub) |

## Версия 2: стъпка по стъпка (на компютъра с играта и GPU)

### 1. Python

1. Инсталирайте Python 3.12 или 3.13 и направете venv в папката на проекта:
   `python -m venv .venv` и `.venv\Scripts\activate`.
2. Инсталирайте PyTorch **с CUDA** от [pytorch.org/get-started](https://pytorch.org/get-started/locally/)
   (Windows → Pip → Python → вашата CUDA версия, копирайте командата).
3. `pip install -r requirements.txt`
4. Проверка: `python -c "import torch; print(torch.cuda.is_available())"` трябва да отпечата `True`.

### 2. Настройки на играта

- **Options → Graphics:** класическа графика (Classic), режим **Windowed Fullscreen**, на основния монитор.
- По време на снимането **не пипайте мишката** — ако е в края на екрана, камерата се мести.

### 3. Картата в World Editor

1. Отворете World Editor → **File → Open Map** → изберете някоя от картите на Blizzard за мултиплейър
   (например от папката Frozen Throne). Изберете карти с различен вид: трева, сняг, пустиня,
   Northrend, гора, подземие.
2. **Scenario → Map Options:** Script Language трябва да е **JASS**.
3. Отворете **Trigger Editor** (F4) → изберете тригера **Melee Initialization** →
   **Edit → Convert to Custom Text** → OK.
4. Изтрийте целия текст на тригера и поставете съдържанието на `game_capture/dataset_trigger.j`.
5. **File → Save Map As** → `dataset_<име>.w3x` (не презаписвайте картата на Blizzard).

Ако при запазване излезе грешка в скрипта, пратете ми точния текст на грешката.

### 4. Снимане

1. В терминала (с активиран venv), в папката на проекта:

   ```bash
   python game_capture/capture.py --map twisted_meadows --shots 800
   ```

   (`--map` е кратко име на картата — различно за всяка карта.)
2. В World Editor: **File → Test Map** (Ctrl+F9). След 1–2 секунди започват да се появяват единици,
   а в терминала — редове като `12 twisted_meadows_0012.jpg ['Human Knight', 'Orc Grunt']`.
3. 800 снимки отнемат ~20 минути. После излезте от играта.
4. Повторете за **4–6 различни карти** (общо 3000–5000 снимки). Последната карта ще се ползва
   само за проверка (validation) — моделът никога няма да я види при обучението.
5. Отворете няколко снимки от `data/screens/` и проверете, че единиците се виждат добре
   (не са скрити под долния панел, не са прекалено малки). Ако нещо не е наред — кажете ми.

Ако не се появяват редове в терминала: проверете дали в `Documents\Warcraft III\CustomMapData\wc3dataset`
се появяват файлове `shot_0.txt`, `shot_1.txt`... При старата Frozen Throne (преди Reforged) файловете
отиват в папката на играта — тогава добавете `--wc3-data "C:\път\до\Warcraft III"`.

### 5. Истински screenshot-и (по желание, но силно препоръчително)

Изиграйте няколко игри (или гледайте replay-и) и натискайте **Print Screen**. Сложете 20–50 снимки в папка
`my_screenshots/`. Notebook-ът ще покаже какво разпознава на тях — това е най-честната проверка, защото
са от истинска игра, а не от нашата карта.

### 6. Обучение и публикуване

1. `jupyter lab` → отворете `warcraft3_screenshots.ipynb` → **Run → Run All Cells**.
2. Последната секция записва `docs/model.onnx`, `docs/model.json` и примерни снимки в `docs/examples/`.
3. Проверете сайта локално: `python -m http.server 8000 --directory docs` → `http://localhost:8000/moonlit.html`.
   (`index.html` използва Jekyll тема и изглежда правилно само в GitHub Pages — вижте "Темата" по-долу.)
4. Качете в GitHub: `git add .`, `git commit -m "Version 2: game screenshots"`, `git push`.

## Как работи сайтът

Безплатният план на Hugging Face вече не позволява Gradio Spaces (грешка 403 "cpu-basic quota limit"),
затова моделът работи **директно в браузъра** на посетителя:

1. Notebook-ът записва модела във формат **ONNX** и го смалява ~3 пъти (int8 quantization).
2. `docs/app.js` го зарежда с [onnxruntime-web](https://onnxruntime.ai/docs/tutorials/web/).
3. `docs/model.json` казва на страницата имената на единиците, размера на снимката, дали моделът е
   multi-label и какъв е прагът — затова страницата работи и с двете версии без промени.

Няма сървър, който да заспива или да има лимити.

### Темата (два стила)

Както в Lesson 2 (fast.ai tinypets използва темата `alembic`), видът на сайта идва от **отделно repository** —
[bobi3f1/wc3-nightelf-theme](https://github.com/bobi3f1/wc3-nightelf-theme), Jekyll тема в стила на
интерфейса на Night Elf в играта. Включва се с два реда в `docs/_config.yml`:

```yaml
remote_theme: bobi3f1/wc3-nightelf-theme@main
plugins:
  - jekyll-remote-theme
```

- `docs/index.html` — страницата с темата (`layout: page`: прозорец като Game Menu в играта);
- `docs/moonlit.html` — втори стил, обикновен HTML без тема (лунна нощ в Ashenvale);
- двете използват един и същ код: `docs/app.js`.

## Публикуване в GitHub Pages

1. Направете **public** repository в GitHub, напр. `warcraft3-classifier` (Pages е безплатен само за public).
2. Качете проекта (`.gitignore` пропуска големите файлове и снимките):

   ```bash
   git init
   git add .
   git commit -m "Warcraft III classifier"
   git branch -M main
   git remote add origin https://github.com/<вашето-име>/warcraft3-classifier.git
   git push -u origin main
   ```

3. **Settings → Pages → Source: Deploy from a branch → Branch: `main`, папка `/docs`** → **Save**.
4. След 1–2 минути сайтът е на `https://<вашето-име>.github.io/warcraft3-classifier/`.

## Gradio (Lesson 2)

`python app.py` → `http://127.0.0.1:7860`. С `intf.launch(share=True)` в `app.py` получавате временен
публичен линк, докато компютърът работи — удобно за презентация.

## Ограничения

- Версия 2 се учи от сцени, които нашата карта създава: единиците стоят една до друга на открито.
  В истинска игра има битки, заклинания, много единици една върху друга — там ще греши повече.
  Затова е важна проверката с истински screenshot-и (стъпка 5).
- Моделът казва **кои** единици има, но не **къде** са и **колко** са (това е object detection — друга задача).
- Сградите и героите не се разпознават (сградите се появяват на снимките, за да се научи да ги пренебрегва).
- Неофициален учебен проект. Warcraft е собственост на Blizzard Entertainment.

## Следващ етап: реален gameplay

Планът към **90% изцяло правилни screenshot-и** е в [REAL_GAMEPLAY_PLAN.md](REAL_GAMEPLAY_PLAN.md).
Това е цел за отделен реален test set, а не вече постигнат или гарантиран резултат.

За етикетиране на собствени Classic gameplay кадри стартирайте:

```powershell
.venv\Scripts\python.exe game_capture\label_gameplay.py
```

Инструкции: [game_capture/GAMEPLAY_GUIDE.md](game_capture/GAMEPLAY_GUIDE.md). Етикетирането е локално и не изисква GPU.
Дръжте всички кадри от една игра/replay само в една група: training, validation или test.
