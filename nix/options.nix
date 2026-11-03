# Options shared by the NixOS and Home Manager modules.
{ lib, pkgs, self }:
let
  inherit (lib) mkOption mkEnableOption types;
  opt = type: default: description: mkOption { inherit type default description; };
  json = pkgs.formats.json { };
in
rec {
  options = {
    enable = mkEnableOption "the island shell";

    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "inputs.island.packages.\${system}.default";
      description = "The island package (before settings and runtime deps are applied).";
    };

    quickshellPackage = mkOption {
      type = types.package;
      default = pkgs.quickshell;
      defaultText = lib.literalExpression "pkgs.quickshell";
      description = "Quickshell build used to run the shell, e.g. the one from the quickshell flake.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = lib.optional (pkgs ? awww) pkgs.awww;
      defaultText = lib.literalExpression "[ pkgs.awww ]";
      example = lib.literalExpression "[ pkgs.awww ]";
      description = ''
        Extra programs put on the shell's PATH. Holds your wallpaper setter:
        `settings.wallpapers.setter` defaults to awww (the swww successor).
        Remember to start `awww-daemon` from your compositor.
      '';
    };

    installFonts = opt types.bool true "Install Inter and Material Symbols (the default fonts).";

    systemd.enable = opt types.bool false ''
      Run the shell as a systemd user service. Off by default: a service does not
      inherit your compositor's PATH, so launching apps can fail. Prefer starting
      `island` from your compositor (e.g. `exec-once = island`).
    '';

    colorsTemplate = mkOption {
      type = types.str;
      readOnly = true;
      description = ''
        Path of the matugen template that produces ~/.config/quickshell/colors.json.
        Point a matugen template at it: `input_path = config.programs.island.colorsTemplate`.
      '';
    };

    extraSettings = mkOption {
      type = json.type;
      default = { };
      example = { look.topGap = 6; };
      description = "Raw settings.json content, merged over `settings` (for keys without an option).";
    };

    settings = {
      look = {
        font = opt types.str "Inter" "UI font family.";
        iconFont = opt types.str "Material Symbols Rounded" "Icon font family.";
        topGap = opt types.int 10 "Pixels between the screen edge and the island (ignored when notch is on).";
        windowGap = opt types.int 0 "Extra pixels reserved under the island, added to your compositor's own window gap (negative pulls windows up).";
        notch = opt types.bool false "Attach the island to the top of the screen like a notch: no gap, flat top corners.";
        shadow = opt types.bool true "Drop shadow under the island.";
        shadowOpacity = opt (types.numbers.between 0.0 1.0) 1.0 "Shadow strength, 0 to 1.";
        shadowBlur = opt (types.numbers.between 0.0 1.0) 1.0 "Shadow softness, 0 (hard) to 1 (very soft).";
        shadowOffset = opt types.int 0 "Pixels the shadow drops below the island.";
        shadowColor = opt types.str "#000000" "Shadow colour.";
        sliderAccent = opt types.bool true "Control-center sliders use the accent colour (false = neutral).";
      };
      clock = {
        timeFormat = opt types.str "HH:mm" "Qt time format (\"h:mm AP\" for 12 hour).";
        dateFormat = opt types.str "dddd, d MMMM" "Qt date format.";
        shortDateFormat = opt types.str "ddd, d MMM" "Compact Qt date format used next to the clock on the hover player.";
      };
      pill = {
        clockWithMedia = opt types.bool true "Keep showing the clock in the pill while media is playing.";
        expandOnMedia = opt types.bool true "Widen the pill (cover art and equalizer) while media is playing.";
        batteryIcon = opt types.bool false "Show the battery as an icon only (no percentage) in the pill. Hidden when there is no battery.";
      };
      behavior = {
        hoverToExpand = opt types.bool true "Expand on hover (false = only through IPC / launcher).";
        hoverDelay = opt types.int 110 "ms before hover expands the island.";
        leaveDelay = opt types.int 300 "ms before it collapses again.";
        mediaPeek = opt types.bool true "Show the track card when the song changes.";
        osdTimeout = opt types.int 1700 "Volume / brightness popup time (ms).";
        notifTimeout = opt types.int 5200 "Notification time (ms).";
        peekTimeout = opt types.int 3200 "Track card time (ms).";
        ipcTimeout = opt types.int 6000 "Auto-close for pages opened through IPC (ms).";
      };
      hub = {
        search = opt types.bool true "Show the app launcher button next to the clock in the hover view.";
        controlCenter = opt types.bool true "Show the control center button next to the clock in the hover view.";
      };
      controlCenter = {
        showBattery = opt types.bool true "Show the battery in the control center.";
      };
      lock = {
        autoLock = opt types.bool true "Lock the session after the idle timeout.";
        timeout = opt types.ints.positive 300 "Seconds of inactivity before auto-lock.";
        onSuspend = opt types.bool true "Lock first when Sleep is chosen from the power menu.";
        wallpaper = opt types.bool true "Show the blurred wallpaper behind the lock screen.";
        pam = opt types.str "login" "PAM service (a file in /etc/pam.d) used to verify the password.";
      };
      power = {
        confirm = opt types.bool true "Ask twice (press again to confirm) before log out, restart and shut down.";
        lock = opt (types.listOf types.str) [ ] "Custom command for Lock (empty = use the built-in island lock screen).";
        logout = opt (types.listOf types.str)
          [ "sh" "-c" "niri msg action quit --skip-confirmation || hyprctl dispatch exit || swaymsg exit || loginctl terminate-user $USER" ]
          "Command for Log out (default tries niri, Hyprland, sway, then loginctl).";
        suspend = opt (types.listOf types.str) [ "systemctl" "suspend" ] "Command for Sleep.";
        reboot = opt (types.listOf types.str) [ "systemctl" "reboot" ] "Command for Restart.";
        poweroff = opt (types.listOf types.str) [ "systemctl" "poweroff" ] "Command for Shut down.";
      };
      wallpapers = {
        dir = opt types.str "~/Pictures/Wallpapers" "Wallpaper folder (`~` is expanded).";
        setter = opt (types.listOf types.str)
          [ "awww" "img" "--transition-type" "fade" "--transition-duration" "1" "%f" ]
          "Command that sets a wallpaper; %f is replaced by the image path.";
        matugenMode = opt (types.enum [ "dark" "light" ]) "dark" "Colour scheme mode passed to matugen.";
        matugenScheme = opt types.str "" "matugen scheme type, e.g. scheme-tonal-spot (empty = default).";
        matugenContrast = opt (types.numbers.between (-1.0) 1.0) 0 "matugen contrast from -1 to 1 (changeable live in the switcher).";
        accentPresets = opt (types.listOf types.str)
          [ "#EF5350" "#FF8A65" "#FFCA28" "#9CCC65" "#26A69A" "#42A5F5" "#7E57C2" "#EC407A" ]
          "Accent swatches offered in the switcher's colour panel (#rrggbb).";
        width = opt types.int 700 "Switcher width in px.";
        cardWidth = opt types.int 200 "Thumbnail width in px (height follows 16:10).";
        loop = opt types.bool true "Wrap around at both ends of the strip.";
      };
      launcher = {
        width = opt types.int 560 "Launcher width in px.";
        rows = opt types.int 6 "Visible result rows.";
        maxResults = opt types.int 40 "Maximum results kept.";
        placeholder = opt types.str "Search apps" "Search box placeholder.";
        terminal = opt (types.listOf types.str) [ "kitty" ] "Prefix for apps that need a terminal.";
      };
      clipboard = {
        width = opt types.int 560 "Clipboard page width in px.";
        rows = opt types.int 6 "Visible rows.";
        maxItems = opt types.int 100 "History entries shown.";
        placeholder = opt types.str "Search clipboard" "Search box placeholder.";
        watch = opt types.bool false ''
          Let the shell run `wl-paste --watch cliphist store` for text and images.
          Leave off if your compositor already does.
        '';
      };
      emoji = {
        width = opt types.int 560 "Emoji picker width in px.";
        columns = opt types.int 10 "Grid columns.";
        rows = opt types.int 5 "Visible grid rows.";
        placeholder = opt types.str "Search emoji and symbols" "Search box placeholder.";
        recentMax = opt types.int 30 "Recently used entries kept.";
        typeAfterCopy = opt types.bool false ''
          Also type the pick into the focused window (needs `wtype`, add it via extraPackages).
        '';
      };
      calendar = {
        firstDay = opt types.int 1 "First day of the week: 0 = Sunday, 1 = Monday ...";
        weekNumbers = opt types.bool false "Show ISO week numbers.";
      };
      tray = {
        columns = opt types.int 6 "Icons per row.";
        hidePassive = opt types.bool false "Hide tray items that report a passive status.";
      };
      keys = {
        vim = opt types.bool true "Vim binds in the launcher, clipboard and wallpaper switcher.";
        launcherStartNormal = opt types.bool false "Open launcher / clipboard in normal mode instead of insert.";
      };
    };
  };

  settingsFile = cfg: json.generate "island-settings.json" (lib.recursiveUpdate cfg.settings cfg.extraSettings);

  # the package with this config baked in
  finalPackage = cfg: cfg.package.override {
    quickshell = cfg.quickshellPackage;
    extraRuntimeDeps = cfg.extraPackages;
    settingsFile = settingsFile cfg;
  };

  fonts = cfg: lib.optionals cfg.installFonts [ pkgs.inter pkgs.material-symbols ];
}
