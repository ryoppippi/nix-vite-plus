{
  lib,
  stdenv,
  fetchurl,
  fetchPnpmDeps,
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

  src = ./npm;

  nativeBuildInputs = [
    makeWrapper
    nodejs
    pnpm_10
    pnpmConfigHook
  ];

  pnpmDeps = fetchPnpmDeps {
    pname = "vite-plus-pnpm-deps";
    inherit version;
    src = ./npm;
    inherit (sourcesData) hash;
    fetcherVersion = 3;
  };

  buildPhase = ''
    runHook preBuild
    chmod -R u+w node_modules/vite-plus/dist/global
    substituteInPlace node_modules/vite-plus/dist/global/create.js \
      --replace-fail \
        'else fs.copyFileSync(src, dest);' \
        'else { fs.copyFileSync(src, dest); fs.chmodSync(dest, 0o644); }'
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    tar xzf ${vpBinary} --strip-components=1 -C $out/bin
    chmod 755 $out/bin/vp

    cp -r node_modules $out/node_modules

    wrapProgram $out/bin/vp \
      --prefix PATH : ${lib.makeBinPath [ nodejs ]}

    runHook postInstall
  '';

  dontStrip = true;

  passthru = {
    updateScript = ./update.ts;
  };

  meta = with lib; {
    inherit version;
    description = "The Unified Toolchain for the Web";
    homepage = "https://viteplus.dev";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "vp";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
  };
}
