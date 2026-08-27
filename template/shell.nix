{ pkgs }:

let
  # Одна версия LLVM на всё: компилятор и clangd. BMI (*.pcm) привязан к
  # версии clang, который его собрал, и clangd другой версии его не прочтёт.
  llvm = pkgs.llvmPackages_21;
in

# llvm.stdenv, а не libcxxStdenv: это clang поверх libstdc++ от gcc.
# Библиотека gcc заметно полнее по ranges (fold_left, enumerate, zip,
# concat — всего этого в libc++ 21 нет вовсе), и ABI совпадает с остальным
# nixpkgs, так что сторонние C++-библиотеки линкуются без сюрпризов.
(pkgs.mkShell.override { stdenv = llvm.stdenv; }) {
  packages = [
    pkgs.just
    pkgs.gdb
    llvm.clang-tools # clangd, clang-format, clang-tidy — ровно той же версии
    pkgs.nixfmt
    pkgs.valgrind
    pkgs.bear
  ];

  # Без этого модуль не собрать: при _FORTIFY_SOURCE glibc подменяет printf
  # и родню на inline-обёртки с внутренней связанностью, а экспортировать
  # такое из модуля нельзя. Заодно снимает жалобу на -O0.
  hardeningDisable = [ "fortify" ];

  shellHook = ''
    # Каталог заголовков libstdc++ спрашиваем у самого компилятора, а не
    # прописываем: store-путь меняется при каждом обновлении nixpkgs.
    export GCC_CXX_INCLUDE=$(
      echo | ''${CXX:-clang++} -xc++ -E -v - 2>&1 \
        | grep -oE '/nix/store/[^ ]*/include/c\+\+/[0-9.]+$' \
        | head -1
    )
    export STD_MODULE_SRC="$GCC_CXX_INCLUDE/bits/std.cc"

    if [ ! -f "$STD_MODULE_SRC" ]; then
      echo "bits/std.cc не найден — нужен libstdc++ от gcc 15 или новее" >&2
    fi

    # clangd не читает NIX_CFLAGS_COMPILE и сам заголовки на NixOS не найдёт.
    # ВАЖНО: каждая строка файла — один целый аргумент, поэтому после
    # -isystem пробела быть не должно, иначе он уедет внутрь пути.
    {
      echo "-std=c++23"
      echo "-Wall"
      echo "-Wextra"
      # Именно эта строка объясняет clangd, что такое 'import std;'.
      # Файл появляется после первой сборки — до неё редактор будет ругаться.
      echo "-fmodule-file=std=$PWD/build/std.pcm"
      # Устаревшие заголовки (strstream и прочие) лежат отдельно, и драйвер
      # clang про этот каталог не знает.
      echo "-isystem$GCC_CXX_INCLUDE/backward"
      echo | ''${CXX:-clang++} -xc++ -E -v - 2>&1 \
        | sed -n '/#include <...> search starts here:/,/End of search list/p' \
        | grep "^ /" \
        | sed "s|^ |-isystem|"
    } > compile_flags.txt

    echo "clang $(''${CXX:-clang++} -dumpversion) + libstdc++ $(basename $(dirname $GCC_CXX_INCLUDE 2>/dev/null) 2>/dev/null)/$(basename $GCC_CXX_INCLUDE 2>/dev/null)"
  '';
}
