#!/usr/bin/env python3
"""Wrapper around pandoc for document conversion.

Usage:
    convert_doc <fmt> <file>       # e.g. convert_doc org fp.md   -> fp.org
    convert_doc <file> <fmt>       # e.g. convert_doc file.docx md -> file.md
    convert_doc <file1> <file2>    # e.g. convert_doc file.docx file.md
                                   #   checks which file exists (source),
                                   #   the other becomes target
"""

import os
import sys
import subprocess

ALLOWED_FORMATS = {
    "docx", "md", "org", "pdf", "html", "txt", "rst", "tex",
    "odt", "epub", "rtf", "markdown", "plain", "json", "csv",
}


class ConvertError(Exception):
    """Raised when argument parsing or validation fails."""


def ext(p: str) -> str:
    return os.path.splitext(p)[1].lstrip(".")


def make_pandoc_command(
    arg1: str,
    arg2: str,
    isfile=None,
) -> list[str]:
    """Parse two CLI arguments and return a pandoc command list.

    Raises ConvertError on invalid input.
    *isfile* is a callable(path) -> bool; defaults to os.path.isfile.
    """
    if isfile is None:
        isfile = os.path.isfile

    # ---- Case 1: arg1 is a bare format, arg2 is a file ---- #
    if arg1 in ALLOWED_FORMATS:
        fmt, src = arg1, arg2
        if not isfile(src):
            raise ConvertError(f"source file '{src}' does not exist")

    # ---- Case 2: arg2 is a bare format, arg1 is a file ---- #
    elif arg2 in ALLOWED_FORMATS:
        fmt, src = arg2, arg1
        if not isfile(src):
            raise ConvertError(f"source file '{src}' does not exist")

    # ---- Case 3: both look like filenames – detect by existence ---- #
    else:
        a_exists = isfile(arg1)
        b_exists = isfile(arg2)

        if a_exists and b_exists:
            raise ConvertError(
                f"both '{arg1}' and '{arg2}' exist – cannot decide which is source"
            )
        if not a_exists and not b_exists:
            raise ConvertError(f"neither '{arg1}' nor '{arg2}' exists")

        if a_exists:
            src, target = arg1, arg2
        else:
            src, target = arg2, arg1

        fmt = ext(target)
        if fmt not in ALLOWED_FORMATS:
            raise ConvertError(
                f"target format '{fmt}' is not supported. "
                f"Allowed: {', '.join(sorted(ALLOWED_FORMATS))}"
            )

        if isfile(target) or os.path.isdir(target):
            raise ConvertError(f"target file '{target}' already exists")

        return ["pandoc", src, "-o", target]

    # ---- Build target path (cases 1 & 2) ---- #
    base = os.path.splitext(src)[0]
    target = f"{base}.{fmt}"

    if isfile(target) or os.path.isdir(target):
        raise ConvertError(f"target file '{target}' already exists")

    return ["pandoc", src, "-o", target]


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <fmt> <file>  |  <file> <fmt>  |  <file1> <file2>",
              file=sys.stderr)
        sys.exit(1)

    try:
        cmd = make_pandoc_command(sys.argv[1], sys.argv[2])
    except ConvertError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    print(f"pandoc: {cmd[1]} -> {cmd[3]}")
    sys.exit(subprocess.run(cmd).returncode)


if __name__ == "__main__":
    main()
