import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import pg from "pg";

const { Client } = pg;
const repositoryRoot = path.resolve(import.meta.dirname, "..", "..");
const databaseURL = process.env.MUGSHOT_QA_DATABASE_URL;
const productionRef = process.env.MUGSHOT_PRODUCTION_PROJECT_REF
  ?? "quskamnfwglctqewwfln";
const sslCAPath = process.env.MUGSHOT_QA_SSL_CA_PATH;

if (!databaseURL) {
  throw new Error("MUGSHOT_QA_DATABASE_URL is required");
}

const parsedURL = new URL(databaseURL);
const projectRefMatch = parsedURL.hostname.match(/^db\.([a-z]+)\.supabase\.co$/);
const projectRef = projectRefMatch?.[1];

if (!projectRef) {
  throw new Error("Remote contracts require a direct Supabase branch database URL");
}
if (projectRef === productionRef) {
  throw new Error("Remote contracts refuse to seed or test the production project");
}

const connect = () => new Client({
  connectionString: databaseURL,
  application_name: "mugshot_alpha_contracts",
  ssl: sslCAPath
    ? {
      ca: fs.readFileSync(sslCAPath, "utf8"),
      rejectUnauthorized: true,
    }
    : { rejectUnauthorized: false },
});

const runSQL = async (source) => {
  const client = connect();
  await client.connect();
  try {
    return await client.query(source);
  } finally {
    await client.end();
  }
};

const stripPsqlDirectives = (source) =>
  source.replace(/^\s*\\[^\n]*(?:\n|$)/gm, "");

const seedPath = path.join(
  repositoryRoot,
  "qa",
  "supabase",
  "seed_alpha_contracts.sql",
);
if (!sslCAPath) {
  console.log(
    "INFO QA TLS is encrypted without CA verification; "
      + "set MUGSHOT_QA_SSL_CA_PATH for verify-full.",
  );
}
await runSQL(fs.readFileSync(seedPath, "utf8"));
console.log("PASS deterministic alpha QA seed");

const testDirectory = path.join(repositoryRoot, "supabase", "tests");
const requestedTests = new Set(process.argv.slice(2));
const testFiles = fs.readdirSync(testDirectory)
  .filter((name) => name.endsWith(".sql"))
  .filter((name) => requestedTests.size === 0 || requestedTests.has(name))
  .sort();

let failureCount = 0;
for (const testFile of testFiles) {
  const source = stripPsqlDirectives(
    fs.readFileSync(path.join(testDirectory, testFile), "utf8"),
  );
  try {
    await runSQL(source);
    console.log(`PASS ${testFile}`);
  } catch (error) {
    failureCount += 1;
    const code = error?.code ?? "unknown";
    const message = error?.message ?? String(error);
    console.error(`FAIL ${testFile}: ${code} ${message}`);
    if (error?.detail) console.error(`  DETAIL ${error.detail}`);
    if (error?.where) console.error(`  WHERE ${error.where}`);
  }
}

console.log(
  `SUMMARY ${testFiles.length - failureCount} passed, `
    + `${failureCount} failed, ${testFiles.length} total`,
);

if (failureCount > 0) {
  process.exitCode = 1;
}
