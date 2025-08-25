// functions/scripts/ciqual_build.mjs
// Usage: node scripts/ciqual_build.mjs "export_CIQUAL.csv"
import fs from "fs";
import { parse } from "csv-parse/sync";

// Columns courantes (peuvent changer selon version CIQUAL) :
const COL_LABEL = ["alim_nom_fr", "alim_nom_fr_2008", "alim_nom", "Nom de l'aliment"].map(s => s.toLowerCase());
const COL_KCAL  = [
  "Energie, Règlement UE Nr. 1169/2011 (kcal/100 g)",
  "Energie, N x facteur Jones, avec fibres  (kcal/100 g)",
  "Energie (kcal/100 g)"
].map(s => s.toLowerCase());
const COL_PROT  = ["Protéines (g/100 g)", "Protides (g/100 g)"].map(s => s.toLowerCase());
const COL_CARB  = ["Glucides (g/100 g)"].map(s => s.toLowerCase());
const COL_FAT   = ["Lipides (g/100 g)"].map(s => s.toLowerCase());

const file = process.argv[2];
if (!file) {
  console.error("❌ Usage: node scripts/ciqual_build.mjs /path/to/CIQUAL.csv");
  process.exit(1);
}
const raw = fs.readFileSync(file, "utf8");

// parse CSV (séparateur ; souvent utilisé dans les exports FR)
const records = parse(raw, { columns: true, skip_empty_lines: true, delimiter: ";" });

// Helper pour trouver la bonne colonne, même si l’intitulé varie
const pickCol = (headerLower, candidates) =>
  candidates.find(c => headerLower.includes(c)) ? candidates.find(c => headerLower.includes(c)) : null;

const headers = Object.keys(records[0] || {}).map(h => h.trim());
const headersLower = headers.map(h => h.toLowerCase());

const colLabel = headers[headersLower.findIndex(h => COL_LABEL.some(c => h.includes(c)))] || headers[0];
const colKcal  = headers[headersLower.findIndex(h => COL_KCAL.some(c => h.includes(c)))]  || null;
const colProt  = headers[headersLower.findIndex(h => COL_PROT.some(c => h.includes(c)))]  || null;
const colCarb  = headers[headersLower.findIndex(h => COL_CARB.some(c => h.includes(c)))]  || null;
const colFat   = headers[headersLower.findIndex(h => COL_FAT.some(c => h.includes(c)))]   || null;

if (!colKcal || !colProt || !colCarb || !colFat) {
  console.error("❌ Colonnes non trouvées. Vérifie le CSV CIQUAL et adapte les intitulés.");
  console.error("Headers détectés:", headers);
  process.exit(1);
}

const toNum = (v) => {
  if (v == null) return 0;
  const s = String(v).replace(",", ".").replace(/\s/g, "");
  const n = parseFloat(s);
  return Number.isFinite(n) ? n : 0;
};

const out = [];
for (const row of records) {
  const name = String(row[colLabel] || "").trim();
  if (!name) continue;

  const kcal = toNum(row[colKcal]);
  const prot = toNum(row[colProt]);
  const carb = toNum(row[colCarb]);
  const fat  = toNum(row[colFat]);

  // un minimum de qualité : toutes valeurs >= 0
  if ([kcal, prot, carb, fat].some(x => x < 0)) continue;

  out.push({
    name,
    kcal: kcal,
    protein: prot,
    carbs: carb,
    fat: fat,
  });
}

// dédoublonnage simple (garde 1er)
const seen = new Set();
const dedup = out.filter(it => {
  const key = it.name.toLowerCase();
  if (seen.has(key)) return false;
  seen.add(key);
  return true;
});

fs.mkdirSync("assets", { recursive: true });
fs.writeFileSync("assets/ciqual_min.json", JSON.stringify(dedup, null, 2), "utf8");
console.log(`✅ Écrit assets/ciqual_min.json (${dedup.length} aliments).`);
