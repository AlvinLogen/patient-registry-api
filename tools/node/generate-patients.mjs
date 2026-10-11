import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { parseArgs } from "node:util";

import { buildDocument } from "./lib/patient.mjs";
import { error } from "node:console";

const { values } = parseArgs({
  options: {
    count: { type: "string", default: "50" },
    seed: { type: "string", default: "20261001" },
    out: { type: "string", default: "../../fixtures/generated/patients.json" },
  },
});

function toInt(name, text) {
  if (!/^\d+$/.test(text)) {
    throw new RangeError(`--${name} must be a non-negative integer`);
  }
  return Number(text);
}

async function main() {
  const count = toInt("count", values.count);
  const seed = toInt("seed", values.seed);
  const outPath = resolve(values.out);

  const document = buildDocument({ count, seed });
  await mkdir(dirname(outPath), { recursive: true });
  await writeFile(outPath, `${JSON.stringify(document, null, 2)}\n`, "utf-8");

  console.log(
    JSON.stringify({
      level: "info",
      msg: "fixtures written",
      count,
      seed,
      out: outPath,
    }),
  );
}

main().catch((error) => {
  console.error(JSON.stringify({ level: "error", msg: error.message }));
  process.exitCode = 1;
});
