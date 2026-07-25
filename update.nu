#!/usr/bin/env nix
#! nix shell --inputs-from . nixpkgs#nushell nixpkgs#nodejs_24 -c nu

const npm_registry = "https://registry.npmjs.org"
const platforms = {
  "x86_64-linux": "linux-x64-gnu"
  "aarch64-linux": "linux-arm64-gnu"
  "x86_64-darwin": "darwin-x64"
  "aarch64-darwin": "darwin-arm64"
}

def root-dir []: nothing -> string {
  $env.FILE_PWD
}

def update-npm-lockfile [version: string] {
  let npm_dir = root-dir | path join "npm"
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

  # Regenerate the lockfile from scratch: reconciling a stale lockfile against
  # a new vite-plus version makes npm fail with ERESOLVE peer conflicts
  rm --force ($npm_dir | path join "package-lock.json")

  ^npm install --package-lock-only --ignore-scripts --prefix $npm_dir
}

def update-sources-json [version: string, platforms_data: record] {
  let sources_path = root-dir | path join "sources.json"
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
  let current_version = (open (root-dir | path join "sources.json") | get version)
  let latest_version = (http get $"($npm_registry)/vite-plus/latest" | get version)

  print $"Current version: ($current_version)"
  print $"Latest version: ($latest_version)"
  print $"Updating vite-plus from ($current_version) to ($latest_version)"

  let platforms_data = (
    $platforms
    | items {|nix_platform, npm_suffix|
      let dist = (
        http get $"($npm_registry)/@voidzero-dev/vite-plus-cli-($npm_suffix)/($latest_version)"
        | get dist
      )
      print $"  ($nix_platform): ($dist.integrity)"
      {$nix_platform: {url: $dist.tarball, hash: $dist.integrity}}
    }
    | reduce -f {} {|it, acc| $acc | merge $it}
  )

  print ""
  print "Updating npm lockfile..."
  update-npm-lockfile $latest_version

  update-sources-json $latest_version $platforms_data
  print $"Updated vite-plus to version ($latest_version)"
}
