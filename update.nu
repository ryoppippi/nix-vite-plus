#!/usr/bin/env nix
#! nix shell --inputs-from . nixpkgs#nushell nixpkgs#bun bun2nix#bun2nix -c nu

const npm_registry = "https://registry.npmjs.org"
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

def update-bun-lockfile [version: string] {
  {
    name: "vp-wrapper"
    version: $version
    private: true
    dependencies: {
      "vite-plus": $version
    }
  }
  | save-json (wrapper-dir | path join "package.json")

  ^bun install --cwd (wrapper-dir) --lockfile-only --save-text-lockfile --ignore-scripts
}

def update-bun-nix [] {
  let bun_nix_path = wrapper-dir | path join "bun.nix"

  ^bun2nix --lock-file (wrapper-dir | path join "bun.lock") --output-file $bun_nix_path

  # bun2nix emits every fetcher it might need in the function head; deadnix
  # drops the unused ones, without which the fmt check in CI fails
  cd (root-dir | path join "dev")
  ^nix fmt -- $bun_nix_path
}

def update-sources-json [version: string, platforms_data: record] {
  {
    version: $version
    platforms: $platforms_data
  }
  | save-json (root-dir | path join "sources.json")
}

def main [] {
  let current_version = open (root-dir | path join "sources.json") | get version
  let latest_version = http get $"($npm_registry)/vite-plus/latest" | get version

  print $"Current version: ($current_version)"
  print $"Latest version: ($latest_version)"
  print $"Updating vite-plus from ($current_version) to ($latest_version)"

  let platforms_data = $platforms
    | items {|nix_platform, npm_suffix|
      let dist = http get $"($npm_registry)/@voidzero-dev/vite-plus-cli-($npm_suffix)/($latest_version)"
        | get dist
      print $"  ($nix_platform): ($dist.integrity)"
      {$nix_platform: {url: $dist.tarball, hash: $dist.integrity}}
    }
    | into record

  print ""
  print "Updating bun lockfile..."
  update-bun-lockfile $latest_version

  print "Regenerating bun.nix..."
  update-bun-nix

  update-sources-json $latest_version $platforms_data
  print $"Updated vite-plus to version ($latest_version)"
}
