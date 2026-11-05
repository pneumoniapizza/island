{ lib
, stdenvNoCC
, runtimeShell
, makeWrapper
, quickshell
, brightnessctl
, networkmanager
, systemd
, coreutils
, findutils
, cliphist
, wl-clipboard
, matugen
  # extra tools on the shell's PATH, e.g. the wallpaper setter: [ pkgs.swww ]
, extraRuntimeDeps ? [ ]
  # bake a settings.json into the wrapper (ISLAND_SETTINGS still wins at runtime)
, settingsFile ? null
}:

let
  runtimeDeps = [
    brightnessctl   # brightness slider + OSD
    networkmanager  # nmcli: Wi-Fi toggle / network name
    systemd         # loginctl
    coreutils       # df, cat
    procps          # top: sysmon process list
    gawk            # sysmon process list
    findutils       # find: wallpaper scan
    cliphist        # clipboard history
    wl-clipboard    # wl-copy / wl-paste
    matugen         # wallpaper -> colour scheme
  ] ++ extraRuntimeDeps;
in
stdenvNoCC.mkDerivation {
  pname = "island";
  version = "0.1.0";

  src = ./.;
  dontBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/island $out/bin
    cp -r shell.qml settings.json config services components modules ipc contrib $out/share/island/

    mkdir -p $out/libexec
    makeWrapper ${lib.getExe quickshell} $out/libexec/island-run \
      --add-flags "-p $out/share/island" \
      --prefix PATH : ${lib.makeBinPath runtimeDeps} \
      ${lib.optionalString (settingsFile != null) "--set-default ISLAND_SETTINGS ${settingsFile}"}

    # `island --ipc` lists every IPC target and function of the running shell
    cat > $out/bin/island <<EOF
    #!${runtimeShell}
    case "\$1" in
      --ipc|ipc-show)
        if ! $out/libexec/island-run ipc show 2>/dev/null; then
          echo "island isn't running, start it with: island" >&2
          exit 1
        fi
        exit 0 ;;
    esac
    exec $out/libexec/island-run "\$@"
    EOF
    chmod +x $out/bin/island

    runHook postInstall
  '';

  meta = {
    description = "Dynamic-island style Quickshell shell: launcher, control center, wallpapers, clipboard";
    mainProgram = "island";
    platforms = lib.platforms.linux;
  };
}
