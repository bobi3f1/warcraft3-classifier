// The classifier page logic, shared by index.html (Night Elf theme) and moonlit.html.
// Both pages have the same elements: #well, #preview, #status, #result, #file, #choose, #empty, #examples, #model-name.
// The same steps as classifier_app.py: the model looks at the whole screenshot and answers for 33600 places on it.
const SIZE = 1280, PLACES = 33600;                 // the model takes a 1280x1280 image

const well = document.getElementById("well");
const preview = document.getElementById("preview");
const status = document.getElementById("status");
const result = document.getElementById("result");
const fileInput = document.getElementById("file");
const marks = document.createElement("canvas");    // the numbered dots, on top of the screenshot
marks.id = "marks";
well.append(marks);
// info = model.json: labels, conf, overlap, model_file, model_name, examples
// (+ example_counts: every unit; example_labels: only which types, for the old map4 examples)
let session, info, truth = null, counted = false;

async function loadModel() {
  info = await (await fetch("model.json?v=yolo26m")).json();
  document.getElementById("model-name").textContent = `Model: ${info.model_name}`;
  for (const name of info.examples) {
    const counts = info.example_counts?.[name];
    const labels = counts ?? info.example_labels?.[name];
    const what = counts ? "unit" : "unit type";
    const button = document.createElement("button");
    button.className = "shot";
    button.type = "button";
    button.setAttribute("aria-pressed", "false");
    button.innerHTML = `<img src="examples/${name}" alt="Example screenshot ${name}" loading="lazy">` +
      (labels ? `<span>${labels.length} ${what}${labels.length > 1 ? "s" : ""} on it</span>` : "");
    button.onclick = () => {
      document.querySelectorAll(".shot").forEach(b => b.setAttribute("aria-pressed", "false"));
      button.setAttribute("aria-pressed", "true");
      show(`examples/${name}`, labels, !!counts);
    };
    document.getElementById("examples").append(button);
  }
  session = await ort.InferenceSession.create(info.model_file, { executionProviders: ["webgpu", "wasm"] });
  status.textContent = "Ready. Add a screenshot or pick one below.";
}

// Same steps as in training: 1280 wide, worker icon hidden, gray bars to make a square, pixels 0-1, channels first
function toTensor(img) {
  const height = Math.round(SIZE * img.naturalHeight / img.naturalWidth);
  const top = Math.floor((SIZE - height) / 2);
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = SIZE;
  const ctx = canvas.getContext("2d", { willReadFrequently: true });
  ctx.fillStyle = "rgb(114, 114, 114)";
  ctx.fillRect(0, 0, SIZE, SIZE);
  ctx.imageSmoothingQuality = "high";
  ctx.drawImage(img, 0, top, SIZE, height);
  ctx.fillStyle = "#000";
  ctx.fillRect(160, top + 465, 60, 60);
  const pixels = ctx.getImageData(0, 0, SIZE, SIZE).data;
  const n = SIZE * SIZE, data = new Float32Array(3 * n);
  for (let i = 0; i < n; i++)
    for (let c = 0; c < 3; c++)
      data[c * n + i] = pixels[i * 4 + c] / 255;
  return { tensor: new ort.Tensor("float32", data, [1, 3, SIZE, SIZE]), top };
}

function iou(a, b) {
  const w = Math.max(0, Math.min(a[2], b[2]) - Math.max(a[0], b[0]));
  const h = Math.max(0, Math.min(a[3], b[3]) - Math.max(a[1], b[1]));
  return w * h / ((a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - w * h);
}

// One { box, label, guesses } per unit, strongest first. Boxes are in pixels of a 1280-wide screenshot.
async function findUnits(img) {
  const { tensor, top } = toTensor(img);
  const output = await session.run({ images: tensor });
  const data = output[session.outputNames[0]].data;          // 52 rows of 33600: x, y, width, height, 48 scores
  const types = info.labels.length, places = [];
  for (let a = 0; a < PLACES; a++) {
    let score = 0, k = 0;
    for (let c = 0; c < types; c++) {
      const s = data[(4 + c) * PLACES + a];
      if (s > score) { score = s; k = c; }
    }
    if (score >= info.conf) places.push({ a, score, k });
  }
  places.sort((p, q) => q.score - p.score);
  // several places fire for one unit: keep the strongest, drop the ones with the same name that overlap it
  const units = [];
  for (const { a, k } of places) {
    const x = data[a], y = data[PLACES + a] - top, w = data[2 * PLACES + a], h = data[3 * PLACES + a];
    const box = [x - w / 2, y - h / 2, x + w / 2, y + h / 2];
    if (units.some(u => u.k === k && iou(box, u.box) >= info.overlap)) continue;
    const guesses = info.labels.map((label, c) => ({ label, p: data[(4 + c) * PLACES + a] }))
                               .sort((p, q) => q.p - p.p).slice(0, 3);
    units.push({ box, k, label: info.labels[k], guesses });
  }
  return units;
}

// The picture of one unit, for its line in the results
function crop(img, box) {
  const scale = img.naturalWidth / SIZE;
  const canvas = document.createElement("canvas");
  canvas.width = box[2] - box[0];
  canvas.height = box[3] - box[1];
  canvas.getContext("2d").drawImage(img, box[0] * scale, box[1] * scale, canvas.width * scale, canvas.height * scale,
                                    0, 0, canvas.width, canvas.height);
  return canvas.toDataURL("image/jpeg", 0.85);
}

function drawMarks(img, units) {
  marks.width = SIZE;
  marks.height = Math.round(SIZE * img.naturalHeight / img.naturalWidth);
  const ctx = marks.getContext("2d");
  ctx.font = "bold 26px system-ui, sans-serif";
  ctx.lineWidth = 5;
  units.forEach((u, i) => {
    const [left, top, right, bottom] = u.box;
    const x = (left + right) / 2, y = bottom - (bottom - top) * 145 / 465;    // where the unit stands (the box is loose)
    ctx.fillStyle = "#ffe600";
    ctx.beginPath();
    ctx.arc(x, y, 7, 0, 2 * Math.PI);
    ctx.fill();
    ctx.strokeStyle = "#000";
    ctx.strokeText(i + 1, x + 11, y - 9);
    ctx.fillText(i + 1, x + 11, y - 9);
  });
}

const percent = p => p < 0.001 ? "under 0.1%" : `${(p * 100).toFixed(1)}%`;

// With known labels (examples), names that are not on the screenshot are crossed out
function compare(units) {
  const left = [...truth], wrong = new Set();
  units.forEach((u, i) => {
    const at = left.indexOf(u.label);
    if (at < 0) wrong.add(i);
    else if (counted) left.splice(at, 1);
  });
  const missed = counted ? left : truth.filter(l => !units.some(u => u.label === l));
  return { wrong, missed };
}

function cards(img, units, wrong) {
  return units.map((u, i) => {
    const [best, ...next] = u.guesses;
    return `<div class="unit${wrong.has(i) ? " wrong" : ""}">
      <img class="crop" src="${crop(img, u.box)}" alt="Unit ${i + 1}">
      <div class="guess">
        <div class="row"><span>${i + 1}. ${best.label}</span><span class="p">${(best.p * 100).toFixed(0)}%</span></div>
        <div class="bar"><div style="width:${best.p * 100}%"></div></div>
        <div class="next">Next: ${next.map(g => `${g.label} ${percent(g.p)}`).join(", ")}</div>
      </div></div>`;
  }).join("");
}

async function classify() {
  if (!session) return;
  status.textContent = "Looking...";
  await new Promise(done => setTimeout(done, 30));   // let the text appear: without WebGPU the model takes ~7 s
  const units = await findUnits(preview);
  drawMarks(preview, units);
  const { wrong, missed } = truth ? compare(units) : { wrong: new Set(), missed: [] };
  status.textContent = units.length ? `Found ${units.length} unit${units.length > 1 ? "s" : ""}.`
                                    : "No units found. Small or hidden units may be missed.";
  result.innerHTML = cards(preview, units, wrong);
  if (truth) {
    result.innerHTML += `<p class="legend">${truth.length - missed.length} of ${truth.length} right. Crossed out: not on the screenshot.</p>` +
      (missed.length ? `<p class="missed">Missed: <span>${missed.join(", ")}</span></p>` : "");
  }
  well.classList.remove("glow");
  void well.offsetWidth;                 // restart the glow animation
  well.classList.add("glow");
}

function show(src, labels = null, exact = false) {
  truth = labels;
  counted = exact;
  result.innerHTML = "";
  marks.width = 0;
  preview.onload = classify;
  preview.src = src;
  preview.hidden = false;
  document.getElementById("empty").hidden = true;
  well.classList.add("filled");
}

function showFile(file) {
  if (!file || !file.type.startsWith("image/")) return;
  document.querySelectorAll(".shot").forEach(b => b.setAttribute("aria-pressed", "false"));
  show(URL.createObjectURL(file));
}

document.getElementById("choose").onclick = () => fileInput.click();
fileInput.onchange = e => showFile(e.target.files[0]);
well.ondragover = e => { e.preventDefault(); well.classList.add("drag"); };
well.ondragleave = () => well.classList.remove("drag");
well.ondrop = e => { e.preventDefault(); well.classList.remove("drag"); showFile(e.dataTransfer.files[0]); };
document.onpaste = e => showFile([...e.clipboardData.files][0]);

loadModel().then(() => { if (preview.src) classify(); })
           .catch(err => status.textContent = "Could not load the model: " + err.message);
