#!/usr/bin/env nix
/*
#! nix shell --inputs-from . nixpkgs#bun nixpkgs#pnpm -c bun
*/

import { join } from "node:path";
import { tmpdir } from "node:os";
import { mkdtemp, writeFile, rm } from "node:fs/promises";

const NPM_REGISTRY = "https://registry.npmjs.org";
const ROOT_DIR = import.meta.dir;

const platforms = {
	"x86_64-linux": "linux-x64-gnu",
	"aarch64-linux": "linux-arm64-gnu",
	"x86_64-darwin": "darwin-x64",
	"aarch64-darwin": "darwin-arm64",
} as const;

type NixPlatform = keyof typeof platforms;

interface NpmDist {
	tarball: string;
	integrity: string;
}

interface SourcesJSON {
	version: string;
	hash: string;
	platforms: Record<NixPlatform, { url: string; hash: string }>;
}

async function fetchLatestVersion(): Promise<string> {
	const url = `${NPM_REGISTRY}/vite-plus/latest`;
	const response = await fetch(url);
	const json = (await response.json()) as { version: string };
	return json.version;
}

async function fetchPlatformDist(
	npmSuffix: string,
	version: string,
): Promise<NpmDist> {
	const url = `${NPM_REGISTRY}/@voidzero-dev/vite-plus-cli-${npmSuffix}/${version}`;
	const response = await fetch(url);
	const json = (await response.json()) as { dist: NpmDist };
	return json.dist;
}

async function getCurrentVersion(): Promise<string | null> {
	const sourcesPath = join(ROOT_DIR, "sources.json");
	const sources: SourcesJSON = await Bun.file(sourcesPath).json();
	return sources.version;
}

async function updatePnpmLockfile(version: string): Promise<void> {
	const npmDir = join(ROOT_DIR, "npm");
	const packageJsonPath = join(npmDir, "package.json");

	const packageJson = {
		name: "vp-wrapper",
		version,
		private: true,
		dependencies: {
			"vite-plus": version,
		},
	};

	await Bun.write(packageJsonPath, JSON.stringify(packageJson, null, 2) + "\n");

	const { $ } = await import("bun");
	await $`pnpm install --lockfile-only --dir ${npmDir}`;
}

async function getPnpmDepsHash(): Promise<string> {
	const { $ } = await import("bun");
	const npmDir = join(ROOT_DIR, "npm");

	const tmpDir = await mkdtemp(join(tmpdir(), "vp-update-"));
	const nixExprPath = join(tmpDir, "default.nix");

	const nixExpr = `
    let pkgs = import <nixpkgs> {};
    in pkgs.fetchPnpmDeps {
      pname = "vp-wrapper";
      version = "0";
      src = ${npmDir};
      hash = "";
      fetcherVersion = 3;
    }
  `;

	await writeFile(nixExprPath, nixExpr);

	try {
		const result =
			await $`nix build --impure --no-link -f ${nixExprPath} 2>&1`.nothrow();
		const output = result.stdout.toString();
		const match = output.match(/got:\s+(sha256-[A-Za-z0-9+/]+=*)/);
		if (!match) {
			throw new Error(`Failed to extract pnpm deps hash from:\n${output}`);
		}
		return match[1];
	} finally {
		await rm(tmpDir, { recursive: true });
	}
}

async function updateSourcesJSON(
	version: string,
	hash: string,
	platformsData: Record<NixPlatform, { url: string; hash: string }>,
): Promise<void> {
	const sourcesPath = join(ROOT_DIR, "sources.json");

	const sourcesData: SourcesJSON = {
		version,
		hash,
		platforms: platformsData,
	};

	await Bun.write(sourcesPath, JSON.stringify(sourcesData, null, 2) + "\n");
}

const currentVersion = await getCurrentVersion();
const latestVersion = await fetchLatestVersion();

console.log(`Current version: ${currentVersion}`);
console.log(`Latest version: ${latestVersion}`);

console.log(`Updating vite-plus from ${currentVersion} to ${latestVersion}`);

const platformsData: Record<NixPlatform, { url: string; hash: string }> =
	{} as any;

for (const [nixPlatform, npmSuffix] of Object.entries(platforms)) {
	const dist = await fetchPlatformDist(npmSuffix, latestVersion);
	platformsData[nixPlatform as NixPlatform] = {
		url: dist.tarball,
		hash: dist.integrity,
	};
	console.log(`  ${nixPlatform}: ${dist.integrity}`);
}

console.log();

console.log("Updating pnpm lockfile...");
await updatePnpmLockfile(latestVersion);

console.log("Computing pnpm deps hash...");
const pnpmDepsHash = await getPnpmDepsHash();
console.log(`  pnpm deps hash: ${pnpmDepsHash}`);

await updateSourcesJSON(latestVersion, pnpmDepsHash, platformsData);
console.log(`Updated vite-plus to version ${latestVersion}`);
