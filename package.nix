{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,
}:
let
  sourcesData = lib.importJSON ./sources.json;
  inherit (sourcesData) version;
  sources = sourcesData.platforms;

  source =
    sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation rec {
  pname = "vite-plus";
  inherit version;

  src = fetchurl {
    inherit (source) url hash;
  };

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.isLinux [
    stdenv.cc.cc.lib
    zlib
  ];

  sourceRoot = ".";

  unpackPhase = ''
    runHook preUnpack
    tar xzf $src --strip-components=1
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 vp $out/bin/vp
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
