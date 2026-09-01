{
  description = "CyberArch Hyprland theme/config (flake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
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

        # Build a home-manager configuration object for this system
        hm = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          modules = [
            ({ config, pkgs, ... }: {
              # Map repo config -> ~/.config/hypr
              home.file.".config/hypr/".source = "${here}/config";

              # Copy assets & scripts at activation
              home.activation.copy-cyberarch-assets = lib.mkAfter ''
                mkdir -p $HOME/.local/share/hyprland/themes/cyberarch
                cp -r ${here}/assets/* $HOME/.local/share/hyprland/themes/cyberarch/ || true
                cp -r ${here}/scripts $HOME/.local/share/hyprland/themes/cyberarch/scripts || true
                echo "CyberArch assets copied to ~/.local/share/hyprland/themes/cyberarch"
              '';
            })
            ({ config, pkgs, ... }: {
              home.username = "rhys";             # 必填：目标用户
              home.homeDirectory = "/home/rhys";  # 可选但推荐
              home.stateVersion = "23.11";        # 已建议加入，避免其他错误
            })

            # Ensure home.stateVersion is defined (avoid module merge errors)
            ({ config, pkgs, ... }: {
              home.stateVersion = "23.11";
            })
          ];
        };
      in {
        # Per-system packages (theme installer)
        # ... 在 per-system 的 in { ... } 区块内替换 packages 段为：

        packages = {
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
              echo "Installed theme assets to $out/share/hyprland/themes/cyberarch"
            '';
          };

          # <-- 关键：导出 activationPackage（derivation）
          homeConfigurations = {
            default = hm.activationPackage;   # 也可额外添加 `rhys = hm.activationPackage;`
          };
        };
        # Expose the full home-manager object at the top level too (for `nix flake show` consumers)
        homeConfigurations = {
          default = hm;
        };

        # Default package for `nix run .`
        defaultPackage = self.packages.${system}.themeInstaller;
      });
}
