{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  libGL,
  libxcb,
  libxkbcommon,
  vulkan-loader,
  wayland,
  herdr-core,
  versionCheckHook,
  pin,
}:

stdenv.mkDerivation {
  pname = "herdr-app";
  inherit (pin) version;

  src = fetchurl pin.sources.${stdenv.hostPlatform.system};

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib # libgcc_s
    libxcb
    libxkbcommon
  ];

  # wgpu (Vulkan, with OpenGL as fallback) and the Wayland backend load these
  # with dlopen. autoPatchelfHook adds them to RUNPATH rather than
  # LD_LIBRARY_PATH, which the app would pass on to every terminal.
  runtimeDependencies = lib.optionals stdenv.hostPlatform.isLinux [
    libGL
    vulkan-loader
    wayland
  ];

  dontConfigure = true;
  dontBuild = true;
  # Patching or stripping would break the Developer ID signature of Herdr.app.
  dontFixup = stdenv.hostPlatform.isDarwin;

  desktopItems = lib.optionals stdenv.hostPlatform.isLinux [
    (makeDesktopItem {
      name = "herdr-app";
      desktopName = "Herdr";
      comment = "Terminals and coding agents that keep running";
      exec = "herdr-app";
      icon = "herdr-app";
      terminal = false;
      categories = [ "Development" ];
      startupWMClass = "herdr-app";
    })
  ];

  # The binary is not installed beside herdr-app.svg: the app takes that
  # layout as a self-updating install (src/update.rs), which a read-only
  # store path cannot be.
  installPhase =
    lib.optionalString stdenv.hostPlatform.isLinux ''
      runHook preInstall

      install -Dm755 herdr-app/herdr-app -t $out/libexec/herdr-app
      install -Dm644 herdr-app/LICENSE herdr-app/THIRD-PARTY-NOTICES -t $out/share/licenses/herdr-app
      install -Dm644 herdr-app/herdr-app.svg $out/share/icons/hicolor/scalable/apps/herdr-app.svg

      # The app looks for hc on PATH before its list of usual install places.
      # A suffix keeps a core the user put on PATH first.
      makeWrapper $out/libexec/herdr-app/herdr-app $out/bin/herdr-app \
        --suffix PATH : ${lib.makeBinPath [ herdr-core ]}

      runHook postInstall
    ''
    # A wrapper would not apply to a Dock launch, and the bundle must stay
    # intact for its signature. The app finds the core on its own: it looks
    # in /run/current-system/sw/bin and ~/.nix-profile/bin.
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      runHook preInstall

      mkdir -p $out/Applications $out/bin
      cp -R Herdr.app $out/Applications/
      ln -s $out/Applications/Herdr.app/Contents/MacOS/Herdr $out/bin/herdr-app

      runHook postInstall
    '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  passthru = {
    inherit herdr-core;
    inherit (pin) core_min;
  };

  meta = {
    description = "Desktop app for persistent terminals and coding agents (upstream release build)";
    homepage = "https://github.com/herdrdev/herdr-app";
    changelog = "https://github.com/herdrdev/herdr-app/blob/v${pin.version}/CHANGELOG.md";
    # The binary also includes libghostty-vt, QuickJS, fonts and icons under
    # other free licenses; see share/licenses/herdr-app/THIRD-PARTY-NOTICES.
    license = with lib.licenses; [
      asl20
      ofl
      mit
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "herdr-app";
    platforms = builtins.attrNames pin.sources;
  };
}
