// The classifier page logic, shared by index.html (Night Elf theme) and moonlit.html.
// Both pages have the same elements: #well, #preview, #status, #result, #file, #choose, #empty, #examples.
const MEAN = [0.485, 0.456, 0.406], STD = [0.229, 0.224, 0.225];   // ImageNet stats, same as fastai

const well = document.getElementById("well");
const preview = document.getElementById("preview");
const status = document.getElementById("status");
const result = document.getElementById("result");
const fileInput = document.getElementById("file");
// info = model.json: labels, multi_label, threshold, width, height, crop, examples (+ example_labels)
let session, info, truth = null;

async function loadModel() {
  info = await (await fetch("model.json")).json();
  for (const name of info.examples) {
    const labels = info.example_labels?.[name];
    const button = document.createElement("button");
    button.className = "shot";
    button.type = "button";
    button.setAttribute("aria-pressed", "false");
    button.innerHTML = `<img src="examples/${name}" alt="Example screenshot ${name}">` +
      (labels ? `<span>${labels.length} unit${labels.length > 1 ? "s" : ""} on it</span>` : "");
    button.onclick = () => {
      document.querySelectorAll(".shot").forEach(b => b.setAttribute("aria-pressed", "false"));
      button.setAttribute("aria-pressed", "true");
      show(`examples/${name}`, labels);
    };
    document.getElementById("examples").append(button);
  }
  session = await ort.InferenceSession.create("model.onnx");
  status.textContent = "Ready. Add a screenshot or pick one below.";
}

// Same steps as fastai: crop the game UI (if model.json says so), squish to width x height,
// divide by 255, normalize, channels first
function toTensor(img) {
  const w = info.width, h = info.height;
  const top = (info.crop_top ?? 0) * img.naturalHeight;
  const bottom = (info.crop_bottom ?? 1) * img.naturalHeight;
  const canvas = document.createElement("canvas");
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext("2d");
  ctx.imageSmoothingQuality = "high";
  ctx.drawImage(img, 0, top, img.naturalWidth, bottom - top, 0, 0, w, h);
  const pixels = ctx.getImageData(0, 0, w, h).data;
  const data = new Float32Array(3 * w * h);
  for (let i = 0; i < w * h; i++)
    for (let c = 0; c < 3; c++)
      data[c * w * h + i] = (pixels[i * 4 + c] / 255 - MEAN[c]) / STD[c];
  return new ort.Tensor("float32", data, [1, 3, h, w]);
}

// One line per unit; with known labels (examples), wrong guesses are crossed out
function bars(list) {
  return list.map(c => {
    const wrong = truth && !truth.includes(c.label);
    return `<div class="unit${wrong ? " wrong" : ""}">
      <div class="row"><span>${c.label}</span><span class="p">${(c.p * 100).toFixed(0)}%</span></div>
      <div class="bar"><div style="width:${c.p * 100}%"></div></div></div>`;
  }).join("");
}

async function classify() {
  if (!session) return;
  status.textContent = "Looking...";
  const output = await session.run({ image: toTensor(preview) });
  const logits = Array.from(output.logits.data);
  if (info.multi_label) {
    // sigmoid: every unit gets its own 0-100% score
    const scores = logits.map((x, i) => ({ label: info.labels[i], p: 1 / (1 + Math.exp(-x)) }))
                         .sort((a, b) => b.p - a.p);
    const found = scores.filter(c => c.p >= info.threshold);
    status.textContent = found.length ? `It found ${found.length} unit type${found.length > 1 ? "s" : ""}.`
                                      : "It found no units. Its closest guesses:";
    result.innerHTML = bars(found.length ? found : scores.slice(0, 3));
    if (truth) {
      const right = found.filter(c => truth.includes(c.label)).length;
      const missed = truth.filter(l => !found.some(c => c.label === l));
      result.innerHTML += `<p class="legend">${right} of ${truth.length} right. Crossed out: not on the screenshot.</p>` +
        (missed.length ? `<p class="missed">Missed: <span>${missed.join(", ")}</span></p>` : "");
    }
  } else {
    // softmax: the scores add up to 100%
    const exps = logits.map(x => Math.exp(x - Math.max(...logits)));
    const sum = exps.reduce((a, b) => a + b);
    result.innerHTML = bars(exps.map((e, i) => ({ label: info.labels[i], p: e / sum }))
                                .sort((a, b) => b.p - a.p).slice(0, 3));
    status.textContent = "";
  }
  well.classList.remove("glow");
  void well.offsetWidth;                 // restart the glow animation
  well.classList.add("glow");
}

function show(src, labels = null) {
  truth = labels;
  result.innerHTML = "";
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
