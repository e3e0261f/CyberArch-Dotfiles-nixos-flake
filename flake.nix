{
  description = "CyberArch Hyprland theme/config (flake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    # Pin home-manager to the matching release to avoid API mismatch
    home-manager.url = "github:nix-community/home-manager/release-23.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, home-manager, flake-utils, ... }:
    let
      here = ./.;
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib  = pkgs.lib;

        # build the home-manager configuration object
        hm = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          modules = [
            ({ config, pkgs, ... }: {
              # map repository config -> ~/.config/hypr
              home.file.".config/hypr/".source = "${here}/config";

              # activation: copy assets & scripts into user share
              home.activation.copy-cyberarch-assets = lib.mkAfter ''
                mkdir -p $HOME/.local/share/hyprland/themes/cyberarch
                cp -r ${here}/assets/* $HOME/.local/share/hyprland/themes/cyberarch/ || true
                cp -r ${here}/scripts $HOME/.local/share/hyprland/themes/cyberarch/scripts || true
                echo "CyberArch assets copied to $HOME/.local/share/hyprland/themes/cyberarch"
              '';
            })

            # minimal required fields for home-manager activation
            ({ config, pkgs, ... }: {
              home.username = "rhys";            # change to target username if you want
              home.homeDirectory = "/home/rhys";
              home.stateVersion = "23.11";
            })
          ];
        };
      in {
        ################################################################
        # Per-system packages and exports
        ################################################################
        packages = {
          # theme installer: copies assets into $out/share and provides an installer in $out/bin
          themeInstaller = pkgs.stdenv.mkDerivation {
            pname = "cyberarch-hypr-theme";
            version = "0.1";
            src = here;
            phases = [ "installPhase" ];
            installPhase = ''
              outdir=$out/share/hyprland/themes/cyberarch
              mkdir -p "$out/share/hyprland/themes/cyberarch"
              cp -r ${here}/assets/* "$out/share/hyprland/themes/cyberarch/" || true
              cp -r ${here}/scripts "$out/share/hyprland/themes/cyberarch/scripts" || true
              cp -r ${here}/config "$out/share/hyprland/themes/cyberarch/config" || true

              # create a small installer script in $out/bin
              mkdir -p $out/bin
              cat > $out/bin/cyberarch-hypr-theme <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# installer: copy theme assets to XDG_DATA_HOME or default to ~/.local/share
target="${XDG_DATA_HOME:-$HOME/.local/share}/hyprland/themes/cyberarch"
mkdir -p "$target"
# copy contents of the package's share dir into target
pkgshare="$(dirname "$0")/../share/hyprland/themes/cyberarch"
if [ -d "$pkgshare" ]; then
  cp -r "$pkgshare/"* "$target/" || true
  echo "Installed CyberArch theme to $target"
else
  echo "Error: package share directory not found: $pkgshare" >&2
  exit 1
fi
EOF
              chmod +x $out/bin/cyberarch-hypr-theme
            '';
          };

          # export activationPackage so home-manager CLI can find it
          homeConfigurations = {
            default = hm.activationPackage;
          };
        };

        ################################################################
        # Top-level homeConfigurations for `nix flake show` and direct usage
        ################################################################
        homeConfigurations = {
          default = hm;
        };

        # default package for `nix run .`
        defaultPackage = self.packages.${system}.themeInstaller;
      });
}
