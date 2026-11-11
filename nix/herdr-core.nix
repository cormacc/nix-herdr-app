{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
  pin,
}:

stdenvNoCC.mkDerivation {
  pname = "herdr-core";
  inherit (pin) version;

  src = fetchurl pin.sources.${stdenvNoCC.hostPlatform.system};

  sourceRoot = ".";

  # Linux: a static-pie binary that needs no patching. hc tells builds apart
  # by their GNU build id, so leave the file byte-identical. macOS: patching
  # would break the Developer ID signature of Herdr Core.app.
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 LICENSE THIRD-PARTY-NOTICES -t $out/share/licenses/herdr-core
  ''
  # hc runs from inside its signed bundle on macOS, as upstream's installer
  # sets it up, so that macOS privacy grants follow the signing identity.
  + lib.optionalString stdenvNoCC.hostPlatform.isDarwin ''
    mkdir -p $out/Applications $out/bin
    cp -R "Herdr Core.app" $out/Applications/
    ln -s "$out/Applications/Herdr Core.app/Contents/MacOS/herdr-core" $out/bin/herdr-core
  ''
  + lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
    install -Dm755 herdr-core -t $out/bin
  ''
  + ''
    ln -s herdr-core $out/bin/hc

    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  # On Darwin the check runs the binary from inside the signed bundle in $out.
  # macOS then adds com.apple.macl to the bundle, and Nix fails to
  # canonicalise the store path ("clearing flags of path ...: Operation not
  # permitted").
  doInstallCheck = !stdenvNoCC.hostPlatform.isDarwin;

  meta = {
    description = "Persistent terminal and coding agent backend for Herdr (upstream release build)";
    homepage = "https://github.com/herdrdev/herdr-core";
    changelog = "https://github.com/herdrdev/herdr-core/blob/v${pin.version}/CHANGELOG.md";
    # The binary also includes libghostty-vt and its dependencies under other
    # free licenses; see share/licenses/herdr-core/THIRD-PARTY-NOTICES.
    license = with lib.licenses; [
      asl20
      mit
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "hc";
    platforms = builtins.attrNames pin.sources;
  };
}
