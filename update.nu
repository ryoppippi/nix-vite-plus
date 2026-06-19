#!/usr/bin/env nix
#! nix shell --inputs-from . nixpkgs#nushell nixpkgs#nodejs_24 -c nu

const npm_registry = "https://registry.npmjs.org"
const platforms = {
  "x86_64-linux": "linux-x64-gnu"
  "aarch64-linux": "linux-arm64-gnu"
  "x86_64-darwin": "darwin-x64"
  "aarch64-darwin": "darwin-arm64"
}

def root_dir []: nothing -> string {
  $env.FILE_PWD
}

def fetch_latest_version []: nothing -> string {
  http get $"($npm_registry)/vite-plus/latest"
  | get version
}

def fetch_platform_dist [npm_suffix: string, version: string]: nothing -> record {
  http get $"($npm_registry)/@voidzero-dev/vite-plus-cli-($npm_suffix)/($version)"
  | get dist
}

def get_current_version []: nothing -> string {
  open (root_dir | path join "sources.json")
  | get version
}

def update_npm_lockfile [version: string] {
  let npm_dir = root_dir | path join "npm"
  let package_json_path = $npm_dir | path join "package.json"
  let package_json = {
    name: "vp-wrapper"
    version: $version
    private: true
    dependencies: {
      "vite-plus": $version
    }
  }

  $package_json
  | to json --indent 2
  | $"($in)\n"
  | save --force $package_json_path

  ^npm install --package-lock-only --ignore-scripts --prefix $npm_dir
}

def update_sources_json [version: string, platforms_data: record] {
  let sources_path = root_dir | path join "sources.json"
  let sources_data = {
    version: $version
    platforms: $platforms_data
  }

  $sources_data
  | to json --indent 2
  | $"($in)\n"
  | save --force $sources_path
}

def main [] {
  let current_version = get_current_version
  let latest_version = fetch_latest_version

  print $"Current version: ($current_version)"
  print $"Latest version: ($latest_version)"
  print $"Updating vite-plus from ($current_version) to ($latest_version)"

  mut platforms_data = {}

  for platform in ($platforms | transpose nix_platform npm_suffix) {
    let dist = fetch_platform_dist $platform.npm_suffix $latest_version
    $platforms_data = $platforms_data | insert $platform.nix_platform {
      url: $dist.tarball
      hash: $dist.integrity
    }
    print $"  ($platform.nix_platform): ($dist.integrity)"
  }

  print ""
  print "Updating npm lockfile..."
  update_npm_lockfile $latest_version

  update_sources_json $latest_version $platforms_data
  print $"Updated vite-plus to version ($latest_version)"
}
