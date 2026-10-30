// The classifier page logic, shared by index.html (Night Elf theme) and moonlit.html.
// Both pages have the same elements: #well, #preview, #status, #result, #file, #choose, #change, #full, #tools,
// #empty, #examples, #model-name.
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
let session, info, truth = null, counted = false, found = [];

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

// A yellow dot where each unit stands, with its number. scale, startX, startY place the 1280-wide screenshot on the canvas.
function drawUnits(ctx, units, scale, startX, startY, withNames) {
  ctx.font = `bold ${withNames ? 16 : 26}px system-ui, sans-serif`;
  ctx.lineWidth = withNames ? 4 : 5;
  units.forEach((u, i) => {
    const [left, top, right, bottom] = u.box;
    const x = startX + scale * (left + right) / 2;
    const y = startY + scale * (bottom - (bottom - top) * 145 / 465);         // where the unit stands (the box is loose)
    const text = withNames ? `${i + 1}. ${u.label}` : i + 1;
    ctx.fillStyle = "#ffe600";
    ctx.beginPath();
    ctx.arc(x, y, 7, 0, 2 * Math.PI);
    ctx.fill();
    ctx.strokeStyle = "#000";
    ctx.strokeText(text, x + 11, y - 9);
    ctx.fillText(text, x + 11, y - 9);
  });
}

function drawMarks(img, units) {
  marks.width = SIZE;
  marks.height = Math.round(SIZE * img.naturalHeight / img.naturalWidth);
  drawUnits(marks.getContext("2d"), units, 1, 0, 0, false);
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
  found = units;
  drawMarks(preview, units);
  if (viewer.open) placeImage();
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
  found = [];
  marks.width = 0;
  preview.onload = classify;
  preview.src = src;
  preview.hidden = false;
  document.getElementById("empty").hidden = true;
  document.getElementById("tools").hidden = false;
  well.classList.add("filled");
}

function showFile(file) {
  if (!file || !file.type.startsWith("image/")) return;
  document.querySelectorAll(".shot").forEach(b => b.setAttribute("aria-pressed", "false"));
  show(URL.createObjectURL(file));
}

document.getElementById("choose").onclick = () => fileInput.click();
document.getElementById("change").onclick = () => fileInput.click();
fileInput.onchange = e => {
  showFile(e.target.files[0]);
  e.target.value = "";                   // so the same file can be chosen again
};
well.ondragover = e => { e.preventDefault(); well.classList.add("drag"); };
well.ondragleave = () => well.classList.remove("drag");
well.ondrop = e => { e.preventDefault(); well.classList.remove("drag"); showFile(e.dataTransfer.files[0]); };
document.onpaste = e => showFile([...e.clipboardData.files][0]);

// ---- the full-screen viewer: wheel or + and - to zoom, drag to move, Esc to close ----
const viewer = document.createElement("dialog");
viewer.id = "viewer";
viewer.setAttribute("aria-label", "The screenshot in full screen");
viewer.innerHTML = `<div class="viewer-stage" id="viewer-stage">
    <img id="viewer-image" alt="The screenshot, zoomed">
    <canvas id="viewer-marks"></canvas>
  </div>
  <div class="viewer-tools">
    <span id="viewer-zoom" aria-live="polite"></span>
    <button id="viewer-out" type="button" aria-label="Zoom out">&minus;</button>
    <button id="viewer-in" type="button" aria-label="Zoom in">+</button>
    <button id="viewer-fit" type="button">Fit</button>
    <button id="viewer-names" type="button">Hide names</button>
    <button id="viewer-close" type="button">Close</button>
  </div>`;
document.body.append(viewer);
const stage = document.getElementById("viewer-stage");
const big = document.getElementById("viewer-image");
const bigMarks = document.getElementById("viewer-marks");
let zoom = 1, shiftX = 0, shiftY = 0, fitWidth = 0, fitHeight = 0, showNames = true, dragFrom = null;

// Keep the picture on screen, move and scale it, and draw the names at their normal size on top
function placeImage() {
  const W = stage.clientWidth, H = stage.clientHeight, w = fitWidth * zoom, h = fitHeight * zoom;
  shiftX = w <= W ? (W - w) / 2 : Math.min(0, Math.max(W - w, shiftX));
  shiftY = h <= H ? (H - h) / 2 : Math.min(0, Math.max(H - h, shiftY));
  big.style.transform = `translate(${shiftX}px, ${shiftY}px) scale(${zoom})`;
  document.getElementById("viewer-zoom").textContent = `${Math.round(zoom * 100)}%`;
  bigMarks.width = W * devicePixelRatio;
  bigMarks.height = H * devicePixelRatio;
  const ctx = bigMarks.getContext("2d");
  ctx.scale(devicePixelRatio, devicePixelRatio);
  if (showNames) drawUnits(ctx, found, w / SIZE, shiftX, shiftY, true);
}

function fitImage() {
  const scale = Math.min(stage.clientWidth / preview.naturalWidth, stage.clientHeight / preview.naturalHeight);
  fitWidth = preview.naturalWidth * scale;
  fitHeight = preview.naturalHeight * scale;
  big.style.width = `${fitWidth}px`;
  big.style.height = `${fitHeight}px`;
  zoom = 1;
  placeImage();
}

// Zoom around one point of the screen, so what is under the mouse stays there
function zoomAt(x, y, factor) {
  const next = Math.min(8, Math.max(1, zoom * factor));
  shiftX = x - (x - shiftX) * next / zoom;
  shiftY = y - (y - shiftY) * next / zoom;
  zoom = next;
  placeImage();
}

const zoomMiddle = factor => zoomAt(stage.clientWidth / 2, stage.clientHeight / 2, factor);

function openViewer() {
  if (preview.hidden) return;
  big.src = preview.src;
  viewer.showModal();
  fitImage();
  viewer.requestFullscreen?.().catch(() => {});     // without it the viewer still fills the browser window
}

preview.onclick = openViewer;
document.getElementById("full").onclick = openViewer;
document.getElementById("viewer-in").onclick = () => zoomMiddle(1.5);
document.getElementById("viewer-out").onclick = () => zoomMiddle(1 / 1.5);
document.getElementById("viewer-fit").onclick = fitImage;
document.getElementById("viewer-close").onclick = () => viewer.close();
document.getElementById("viewer-names").onclick = e => {
  showNames = !showNames;
  e.target.textContent = showNames ? "Hide names" : "Show names";
  placeImage();
};
stage.onwheel = e => { e.preventDefault(); zoomAt(e.clientX, e.clientY, e.deltaY < 0 ? 1.25 : 0.8); };
stage.ondblclick = e => zoomAt(e.clientX, e.clientY, zoom > 1 ? 1 / zoom : 2.5);
stage.onpointerdown = e => {
  dragFrom = [e.clientX, e.clientY];
  stage.setPointerCapture(e.pointerId);
  stage.classList.add("moving");
};
stage.onpointermove = e => {
  if (!dragFrom) return;
  shiftX += e.clientX - dragFrom[0];
  shiftY += e.clientY - dragFrom[1];
  dragFrom = [e.clientX, e.clientY];
  placeImage();
};
stage.onpointerup = stage.onpointercancel = () => {
  dragFrom = null;
  stage.classList.remove("moving");
};
viewer.onkeydown = e => {
  if (e.key === "+" || e.key === "=") zoomMiddle(1.5);
  if (e.key === "-") zoomMiddle(1 / 1.5);
  if (e.key === "0") fitImage();
};
viewer.onclose = () => { if (document.fullscreenElement) document.exitFullscreen(); };
document.onfullscreenchange = () => { if (!document.fullscreenElement && viewer.open) viewer.close(); };
window.addEventListener("resize", () => { if (viewer.open) fitImage(); });

loadModel().then(() => { if (preview.src) classify(); })
           .catch(err => status.textContent = "Could not load the model: " + err.message);
