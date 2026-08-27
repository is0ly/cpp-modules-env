{
  description = "Окружение и шаблон для проектов на C++ с модулями";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      templates.default = {
        path = ./template;
        description = "Проект на C++23: clang, libc++, import std, clangd";
      };

      # Разовый вход без создания проекта: nix develop github:is0ly/cpp-env
      devShells.${system}.default = import ./template/shell.nix { inherit pkgs; };
    };
}
