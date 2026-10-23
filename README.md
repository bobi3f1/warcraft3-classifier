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

## Версия 3 (в процес): първо „къде“, после „коя“

Защо версия 2 изглежда, че гадае: една единица е ~50×60 пиксела, под 0.5% от screenshot-а. Един модел
трябваше едновременно да намери малките фигурки и да ги разпознае сред 48 класа, а multi-label етикетът
не казва **колко** са. Затова версия 3 разделя задачата:

1. **Детектор** (`warcraft3_detector.ipynb`, YOLO от `ultralytics`) намира рамка за всяка единица → и броя.
2. **Класификатор** (`warcraft3_unit_crops.ipynb`) гледа само изрязаната рамка и избира 1 от 48 — softmax,
   както Lesson 1 / Версия 1.

Данните за класификатора са solo снимките (`data/single_units`, един тип, 1–3 копия). JASS скриптът ги
поставя на известни места спрямо камерата, затова позицията на всяко копие на екрана се пресмята с
перспективна проекция и се изрязва без ръчно маркиране (3967 crop-а).

| Опит | accuracy (непозната solo карта `single-valid1`, 167 crop-а) |
|---|---|
| `convnext_tiny.fb_in22k`, 224×224, `fine_tune(8, 2e-3)`, fp16 | **98.8%** (2 грешки: Priest→Sorceress, Hippogryph Rider→Gryphon Rider) |

- Validation е малък: само 3–4 crop-а на клас, всички с по едно копие. Нужна е още една solo карта
  (validation) и отделна test карта.
- Crop-овете са изрязани по точната формула; рамките от детектора ще са малко различни.
- На GTX 1080 Ti обучението понякога внезапно дава `nan` в случаен batch — `SaveModelCallback` +
  `TerminateOnNaNCallback`, както във версия 2.

**Детекторът** (`yolo26s`, 1280 px, рамки по същата формула, учен само на solo снимки; mosaic
аугментацията слепва 4 solo снимки в една смесена сцена). „Изцяло вярна снимка“ = същите единици **и**
същият брой от всяка.

| | Solo карта `single-valid1` (167 снимки) | Смесени сцени map4 (796) — изцяло верни | намерени | грешни „намерени“ |
|---|---|---|---|---|
| Версия 2 (за сравнение) | — | 18% | 65% | 900 |
| YOLO | 93.4% (брой верен: 94.6%) | 37.2% | 67.3% | 230 |
| + една рамка на единица (IoU > 0.5) | **95.8%** | 37.6% | 66.7% | 211 |
| + crop класификаторът преименува всяка рамка | **95.8%** | **42.8%** | **70.5%** | **134** |

- На map4 знаем само кои единици има, не колко (старият `labels.csv`), затова там сравняваме имената.
  Детекторът не е виждал смесени сцени — затова е много по-слаб там. Следващите данни трябва да са
  смесени сцени с позиции (новият `dataset_trigger.j` → `data/units.csv`).
- Най-добрата епоха е 20 от 30: в епоха 26 видеокартата спря с `CUDA error: an illegal instruction`
  (заедно със случайните `nan` — признак за нестабилна GPU: температура/overclock).
- Прагът `conf` = 0.3 е избран по същата solo validation карта; нужна е и отделна test карта.

### Към 98–99% на истински screenshot-и: данни и обучение в Kaggle

Главната грешка досега: детекторът пропуска единици, когато стоят близо една до друга — solo снимките
никога не показват това. Истинската игра добавя битки, заклинания, герои, кръгове на избрани единици.
Затова трябват три вида нови данни:

| Данни | Колко | Какво оправя |
|---|---|---|
| Смесени сцени с новия `dataset_trigger.j` (тълпи, армии, битки, герои, ефекти) | 4 training карти × 800 + 1 validation + 1 test карта × 400 | пропуснатите единици в тълпа, броенето |
| Solo test карта (`capture_single.py --map single-test1 --split test`) | 1 карта | честна проверка на отделните единици |
| Истински screenshot-и от игри (`my_screenshots/train`, `my_screenshots/test`) | поне 100 + 100 | всичко, което генераторът не показва; `test` е проверката за 98–99% |

**1. Смесени сцени.** Поставете новия `game_capture/dataset_trigger.j` в World Editor (стъпка 3 по-горе),
на карти с **различен терен** (лято, зима, пустиня, гора, Northrend, подземие). Името в `--map` решава
ролята: с `valid` → validation, с `test` → test, с `trial` → не се използва, всичко друго → training.
Първо кратка проба, после пълният запис:

```bash
python game_capture/capture.py --map mixed-trial --shots 30
```

```bash
python game_capture/capture.py --map mixed-train1 --shots 800
```

(`mixed-train2…4`, `mixed-valid1` и `mixed-test1` — с `--shots 400` — всеки на **друга** карта.) В пробата
проверете в `data/units.csv`, че има редове, и в няколко снимки, че има битки и тълпи. Новият JASS още не е
пускан в играта — ако World Editor покаже грешка, пратете ми текста.

**2. Истински screenshot-и.** Играйте skirmish срещу компютъра или гледайте replay-и с класическа графика и
натискайте **Print Screen** (снимките отиват в `Documents\Warcraft III\ScreenShots`). Разнообразие: четирите
раси, различни карти, битки, бази, ден и нощ. Копирайте около половината в `my_screenshots/train/`, а другата
половина — **от други игри** — в `my_screenshots/test/`. После:

```bash
python prelabel_screenshots.py
```

Моделът рисува чернови в `labels_draft/`. Поправете ги в [makesense.ai](https://www.makesense.ai) (работи в
браузъра, снимките не се качват никъде): **Object Detection** → заредете снимките от една папка → етикети от
`my_screenshots/classes.txt` → *Actions → Import Annotations → YOLO* (файловете от `labels_draft/`) →
поправете → *Actions → Export Annotations → YOLO* → разархивирайте в `labels/` до снимките.
Правила: рамка само за 48-те единици (не за герои, сгради, creep-ове, призовани същества); рисувайте като
черновите — от малко над главата до малко под краката, около два пъти по-широко от единицата; всяка видима
единица получава рамка, дори ако е частично закрита.

**3. Kaggle.**

```bash
python make_kaggle_dataset.py
```

Качете `kaggle_dataset.zip` в Kaggle → *Datasets → New Dataset* (private). После *Create → New Notebook →
File → Import Notebook* с `warcraft3_unit_crops.ipynb`; *Add Input* → вашия dataset; *Settings →
Accelerator: GPU T4 ×2, Internet: on*; *Save Version → Save & Run All*. Когато свърши, направете същото с
`warcraft3_detector.ipynb`, като добавите като input и **output-а** на първия notebook (там е
`unit_classifier.pkl`). Детекторът (`yolo26m`, 1280 px) спира сам след 10 часа (`HOURS`). Свалете от
*Output*: `models/detector/weights/best.pt`, `best.onnx`, `thresholds.json` и `unit_crops/unit_classifier.pkl`.

Честно: 98–99% на истински screenshot-и не е гарантирано. Генерираните сцени помагат много, но най-силно
влияят истинските screenshot-и в training — колкото повече и по-разнообразни, толкова по-добре.

## Файлове

| Файл | Какво прави |
|---|---|
| `warcraft3_screenshots.ipynb` | Версия 2: обучение на multi-label модел върху screenshot-и + export за сайта |
| `warcraft3_classifier.ipynb` | Версия 1 (обучена): сваляне от интернет → почистване → обучение → export |
| `warcraft3_unit_crops.ipynb` | Версия 3: изрязва единиците от solo снимките и обучава класификатор (1 от 48) |
| `warcraft3_detector.ipynb` | Версия 3: YOLO детектор — рамка и клас за всяка единица, т.е. и броя (ultralytics) |
| `game_capture/dataset_trigger_single.j`, `capture_single.py` | Solo снимки: един тип единица, 1–3 копия, на известни места ([инструкции](game_capture/SINGLE_UNIT_CAPTURE.md)) |
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

За версия 3 (от 23.10.2026) скриптът записва и **мястото на всяка единица**: `capture.py` добавя в
`data/units.csv` по един ред на единица (`fname,label,x,y,zoom`), с повторенията. От тях
`screen_box()` в `warcraft3_detector.ipynb` пресмята рамките за детектора. Старите карти в World
Editor трябва да получат новия текст на `dataset_trigger.j` (стъпка 3). Новият JASS още не е пробван
в играта — направете кратка проба (`--shots 30`) и вижте дали `data/units.csv` се пълни.

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
