{
  lib,
  stdenv,
  fetchurl,
  buildNpmPackage,
  makeWrapper,
  nodejs,
  oxfmt,
  oxlint,
  tsgolint,
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

  nodeModules = buildNpmPackage {
    pname = "vite-plus-node-modules";
    inherit version;

    src = ./npm;

    inherit (sourcesData) npmDepsHash;

    dontBuild = true;

    postConfigure = ''
      chmod -R u+w node_modules/vite-plus/dist/global
      substituteInPlace node_modules/vite-plus/dist/global/create.js \
        --replace-fail \
          'else fs.copyFileSync(src, dest);' \
          'else { fs.copyFileSync(src, dest); fs.chmodSync(dest, 0o644); }'
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r node_modules $out/node_modules
      runHook postInstall
    '';
  };
in
stdenv.mkDerivation {
  pname = "vite-plus";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    tar xzf ${vpBinary} --strip-components=1 -C $out/bin
    chmod 755 $out/bin/vp

    ln -s ${nodeModules}/node_modules $out/node_modules

    wrapProgram $out/bin/vp \
      --prefix PATH : ${lib.makeBinPath [
        nodejs
        oxfmt
        oxlint
        tsgolint
      ]}

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
