{
  lib,
  stdenv,
  autoPatchelfHook,
  fetchPnpmDeps,
  fetchurl,
  makeWrapper,
  nodejs,
  pnpm_10,
  pnpmConfigHook,
}:
let
  sourcesData = lib.importJSON ./sources.json;
  inherit (sourcesData) version;
  sources = sourcesData.platforms;

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  vpBinary = fetchurl {
    inherit (source) url hash;
  };

in
stdenv.mkDerivation {
  pname = "vite-plus";
  inherit version;

  src = ./wrapper;

  nativeBuildInputs = [
    pnpm_10
    pnpmConfigHook
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  # nodejs is a host dependency so that fixupPhase resolves the
  # `#!/usr/bin/env node` shebangs shipped inside node_modules against it.
  buildInputs = [
    nodejs
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  # The JS side of vp, installed from wrapper/pnpm-lock.yaml. wrapper/pnpm-workspace.yaml
  # makes it a flat tree of real files, since installPhase moves it into $out as is.
  pnpmDeps = fetchPnpmDeps {
    pname = "vite-plus-wrapper";
    inherit version;
    src = ./wrapper;
    pnpm = pnpm_10;
    fetcherVersion = 4;
    hash = sourcesData.pnpmDepsHash;
  };

  buildPhase = ''
    runHook preBuild
    chmod -R u+w node_modules/vite-plus/dist/create
    substituteInPlace node_modules/vite-plus/dist/create/bin.js \
      --replace-fail \
        'else fs.copyFileSync(src, dest);' \
        'else { fs.copyFileSync(src, dest); fs.chmodSync(dest, 0o644); }'

    # The npm tarball ships templates/generator/bin/index.ts executable, so
    # pnpmConfigHook's patchShebangs already pointed its `#!/usr/bin/env node`
    # at the build's Node. `vp create` copies templates/ into the user's new
    # project, where a store path must never appear: restore the shebang and
    # drop the exec bit so fixupPhase leaves it alone too.
    find node_modules/vite-plus/templates -type f -perm -u+x \
      -exec sed -i -E '1s|^#!/nix/store/[^/]+/bin/node$|#!/usr/bin/env node|' {} + \
      -exec chmod a-x {} +

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    tar xzf ${vpBinary} --strip-components=1 -C $out/bin
    chmod 755 $out/bin/vp

    find node_modules -name '.bin' -type d -exec rm -rf {} + 2>/dev/null || true
    mv node_modules $out/node_modules

    wrapProgram $out/bin/vp \
      --prefix PATH : ${lib.makeBinPath [ nodejs ]}

    ln -s vp $out/bin/vpr
    ln -s vp $out/bin/vpx

    runHook postInstall
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck
    tmpcheck=$(mktemp -d)
    echo "${nodejs.version}" > "$tmpcheck/.node-version"
    output=$(cd "$tmpcheck" && $out/bin/vp --version 2>&1)
    echo "$output" | grep -q "vp v${version}"
    runHook postInstallCheck
  '';

  dontStrip = true;

  passthru = {
    updateScript = ./update.nu;
  };

  meta = with lib; {
    inherit version;
    description = "The Unified Toolchain for the Web";
    homepage = "https://viteplus.dev";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "vp";
    platforms = import ./nix/systems.nix;
    maintainers = with maintainers; [ ryoppippi ];
  };
}
