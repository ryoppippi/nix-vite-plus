#!/usr/bin/env nix
/*
#! nix shell --inputs-from . nixpkgs#bun nixpkgs#oxfmt -c bun
*/

import { join } from "node:path";

const NPM_REGISTRY = "https://registry.npmjs.org";

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
	const sourcesPath = join(import.meta.dir, "sources.json");
	const sources: SourcesJSON = await Bun.file(sourcesPath).json();
	return sources.version;
}

async function updateSourcesJSON(
	version: string,
	platformsData: Record<NixPlatform, { url: string; hash: string }>,
): Promise<void> {
	const sourcesPath = join(import.meta.dir, "sources.json");

	const sourcesData: SourcesJSON = {
		version,
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

await updateSourcesJSON(latestVersion, platformsData);
console.log(`Updated vite-plus to version ${latestVersion}`);

console.log("Formatting with oxfmt...");
const { $ } = await import("bun");
await $`oxfmt sources.json`.quiet();
console.log("Done!");
