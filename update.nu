#!/usr/bin/env nix
#! nix shell --inputs-from . nixpkgs#nushell nixpkgs#pnpm -c nu

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

def update_pnpm_lockfile [version: string] {
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

  ^pnpm install --lockfile-only --dir $npm_dir
}

def get_pnpm_deps_hash [system: string]: nothing -> string {
  let npm_dir = root_dir | path join "npm"
  let platform_config = $npm_dir | path join "platforms" $"($system).yaml"
  let root_dir_json = root_dir | to json
  let nix_expr = $"
    let
      flake = builtins.getFlake ($root_dir_json);
      pkgs = import flake.inputs.nixpkgs {};
      npmDir = ($npm_dir);
      platformConfig = ($platform_config);
      npmSrc = pkgs.runCommand \"vp-wrapper-source-($system)\" {} ''
        cp -r ${npmDir}/. \"$out/\"
        chmod -R u+w \"$out\"
        cp ${platformConfig} \"$out/pnpm-workspace.yaml\"
        rm -rf \"$out/platforms\"
      '';
    in pkgs.fetchPnpmDeps {
      pname = \"vp-wrapper\";
      version = \"0\";
      src = npmSrc;
      hash = \"\";
      fetcherVersion = 3;
    }
  "
  let result = do {
    ^nix build --impure --no-link --expr $nix_expr
  } | complete
  let output = [$result.stdout $result.stderr] | str join
  let hashes = $output | parse --regex 'got:\s+(?<hash>sha256-[A-Za-z0-9+/]+=*)'

  if ($hashes | is-empty) {
    error make { msg: $"Failed to extract pnpm deps hash from:\n($output)" }
  }

  $hashes | first | get hash
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
  print "Updating pnpm lockfile..."
  update_pnpm_lockfile $latest_version

  print "Computing pnpm deps hashes..."
  for platform in ($platforms | transpose nix_platform npm_suffix) {
    let pnpm_deps_hash = get_pnpm_deps_hash $platform.nix_platform
    $platforms_data = $platforms_data | update $platform.nix_platform {
      ...($platforms_data | get $platform.nix_platform)
      pnpmHash: $pnpm_deps_hash
    }
    print $"  ($platform.nix_platform): ($pnpm_deps_hash)"
  }

  update_sources_json $latest_version $platforms_data
  print $"Updated vite-plus to version ($latest_version)"
}
