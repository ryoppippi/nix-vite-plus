#!/usr/bin/env nix
#! nix shell --inputs-from . nixpkgs#nushell nixpkgs#pnpm_10 -c nu

const npm_registry = "https://registry.npmjs.org"
const fake_hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
const platforms = {
  "x86_64-linux": "linux-x64-gnu"
  "aarch64-linux": "linux-arm64-gnu"
  "aarch64-darwin": "darwin-arm64"
}

def root-dir []: nothing -> string {
  $env.FILE_PWD
}

def wrapper-dir []: nothing -> string {
  root-dir | path join "wrapper"
}

# `save` writes exactly what it is given, so re-add the trailing newline every
# other tool in the repo expects of a text file
def save-json [path: path]: record -> nothing {
  to json --indent 2
  | $"($in)\n"
  | save --force $path
}

def write-wrapper-package-json [version: string] {
  {
    name: "vp-wrapper"
    version: $version
    private: true
    dependencies: {
      "vite-plus": $version
    }
  }
  | save-json (wrapper-dir | path join "package.json")
}

def update-pnpm-lockfile [] {
  ^pnpm install --dir (wrapper-dir) --lockfile-only --ignore-scripts
}

def fetch-platforms [version: string]: nothing -> record {
  $platforms
  | items {|nix_platform, npm_suffix|
    let dist = http get $"($npm_registry)/@voidzero-dev/vite-plus-cli-($npm_suffix)/($version)"
      | get dist
    print $"  ($nix_platform): ($dist.integrity)"
    {$nix_platform: {url: $dist.tarball, hash: $dist.integrity}}
  }
  | into record
}

# fetchPnpmDeps is a fixed-output derivation, so its hash is learnt by building
# it against the placeholder in sources.json and reading the hash Nix reports.
def pnpm-deps-hash []: nothing -> string {
  let build = ^nix build $"(root-dir)#vp.pnpmDeps" --no-link | complete
  let got = $build.stderr | parse --regex 'got:\s+(?<hash>sha256-\S+)'
  if ($got | is-empty) {
    error make {msg: $"building the pnpm dependencies failed:\n($build.stderr)"}
  }
  $got | first | get hash
}

def update-sources-json [version: string, pnpm_deps_hash: string, platforms_data: record] {
  {
    version: $version
    pnpmDepsHash: $pnpm_deps_hash
    platforms: $platforms_data
  }
  | save-json (root-dir | path join "sources.json")
}

def main [] {
  let current_version = open (wrapper-dir | path join "package.json") | get dependencies.vite-plus
  let latest_version = http get $"($npm_registry)/vite-plus/latest" | get version

  print $"Current version: ($current_version)"
  print $"Latest version: ($latest_version)"

  write-wrapper-package-json $latest_version
  main sync
}

# Derive everything else from the vite-plus version that wrapper/package.json
# pins, so a dependency bot only has to bump that one field.
def "main sync" [] {
  let version = open (wrapper-dir | path join "package.json") | get dependencies.vite-plus
  print $"Syncing sources.json with vite-plus ($version)"
  write-wrapper-package-json $version

  print "Fetching the native binaries..."
  let platforms_data = fetch-platforms $version

  print "Updating pnpm lockfile..."
  update-pnpm-lockfile

  print "Computing the pnpm dependency hash..."
  update-sources-json $version $fake_hash $platforms_data
  update-sources-json $version (pnpm-deps-hash) $platforms_data
  print $"Synced vite-plus ($version)"
}
