#!/usr/bin/env bash
set -euo pipefail

#---------------------------------------------------------------------------#
#-                       LaTeX Automated Compiler                          -#
#-                          <By Huangrui Mo>                               -#
#- Copyright (C) Huangrui Mo <huangrui.mo@gmail.com>                       -#
#- This is free software: you can redistribute it and/or modify it         -#
#- under the terms of the GNU General Public License as published by       -#
#- the Free Software Foundation, either version 3 of the License, or       -#
#- (at your option) any later version.                                     -#
#---------------------------------------------------------------------------#

usage() {
    echo "Usage: $0 [<l|p|x>< |a|b>] [filename.tex]"
    echo
    echo "TeX engine: l=lualatex, p=pdflatex, x=xelatex"
    echo "Bibliography: a=bibtex, b=biber, omitted=none"
    echo
    echo "Defaults: mode=xa, filename=Thesis.tex"
    echo "Backend: ARTRATEX_BACKEND=auto|tectonic|legacy (default: auto)"
    echo "Output:  ARTRATEX_OUTPUT_DIR=output/pdf"
    echo "Viewer:  ARTRATEX_OPEN_PDF=1 to open the generated PDF"
}

Mode="xa"
SourceFile="Thesis.tex"

case "$#" in
    0)
        ;;
    1)
        if [[ "$1" == "-h" || "$1" == "--help" ]]; then
            usage
            exit 0
        elif [[ "$1" == *.tex ]]; then
            SourceFile="$1"
        else
            Mode="$1"
        fi
        ;;
    2)
        Mode="$1"
        SourceFile="$2"
        ;;
    *)
        usage
        exit 2
        ;;
esac

if [[ ! -f "$SourceFile" ]]; then
    echo "Error: source file not found: $SourceFile" >&2
    exit 2
fi

case "$Mode" in
    *l*) TexCompiler="lualatex" ;;
    *p*) TexCompiler="pdflatex" ;;
    *)   TexCompiler="xelatex" ;;
esac

if [[ "$Mode" == *a* ]]; then
    BibCompiler="bibtex"
elif [[ "$Mode" == *b* ]]; then
    BibCompiler="biber"
else
    BibCompiler=""
fi

ProjectRoot="$(pwd -P)"
OutputDir="${ARTRATEX_OUTPUT_DIR:-output/pdf}"
Backend="${ARTRATEX_BACKEND:-auto}"
OpenPdf="${ARTRATEX_OPEN_PDF:-0}"
SourceBase="$(basename "$SourceFile")"
DocumentName="${SourceBase%.tex}"

mkdir -p "$OutputDir"

if [[ "$OutputDir" = /* ]]; then
    OutputDirAbs="$OutputDir"
else
    OutputDirAbs="$ProjectRoot/$OutputDir"
fi

if [[ "$Backend" != "auto" && "$Backend" != "tectonic" && "$Backend" != "legacy" ]]; then
    echo "Error: ARTRATEX_BACKEND must be auto, tectonic, or legacy." >&2
    exit 2
fi

if [[ "$Backend" == "auto" ]]; then
    if command -v "$TexCompiler" >/dev/null 2>&1 &&
       { [[ -z "$BibCompiler" ]] || command -v "$BibCompiler" >/dev/null 2>&1; }; then
        Backend="legacy"
    elif command -v tectonic >/dev/null 2>&1; then
        Backend="tectonic"
    else
        echo "Error: neither $TexCompiler nor tectonic is available." >&2
        exit 127
    fi
fi

if [[ "$Backend" == "tectonic" ]]; then
    if ! command -v tectonic >/dev/null 2>&1; then
        echo "Error: tectonic is not installed." >&2
        exit 127
    fi

    echo "Compiling $SourceFile with Tectonic..."
    tectonic -X compile "$SourceFile" \
        --outdir "$OutputDir" \
        --keep-logs \
        --keep-intermediates
else
    if ! command -v "$TexCompiler" >/dev/null 2>&1; then
        echo "Error: $TexCompiler is not installed." >&2
        exit 127
    fi
    if [[ -n "$BibCompiler" ]] && ! command -v "$BibCompiler" >/dev/null 2>&1; then
        echo "Error: $BibCompiler is not installed." >&2
        exit 127
    fi

    mkdir -p "$OutputDir/Tex"
    export TEXINPUTS="$ProjectRoot//:${TEXINPUTS:-}"
    export BIBINPUTS="$ProjectRoot//:${BIBINPUTS:-}"
    export BSTINPUTS="$ProjectRoot//:${BSTINPUTS:-}"

    echo "Compiling $SourceFile with $TexCompiler ${BibCompiler:-without bibliography processor}..."
    "$TexCompiler" -interaction=nonstopmode -halt-on-error \
        -output-directory="$OutputDir" "$SourceFile"

    if [[ -n "$BibCompiler" ]]; then
        (
            cd "$OutputDirAbs"
            "$BibCompiler" "$DocumentName"
        )
        "$TexCompiler" -interaction=nonstopmode -halt-on-error \
            -output-directory="$OutputDir" "$SourceFile"
        "$TexCompiler" -interaction=nonstopmode -halt-on-error \
            -output-directory="$OutputDir" "$SourceFile"
    fi
fi

PdfPath="$OutputDir/$DocumentName.pdf"
if [[ ! -f "$PdfPath" ]]; then
    echo "Error: compilation finished without producing $PdfPath" >&2
    exit 1
fi

echo "Finished: $PdfPath"

if [[ "$OpenPdf" == "1" ]]; then
    case "$(uname -s)" in
        Darwin) open "$PdfPath" ;;
        Linux)
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$PdfPath"
            fi
            ;;
    esac
fi
