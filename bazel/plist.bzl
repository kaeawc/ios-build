"""Info.plist fragments written from Starlark dicts.

Xcode generates Info.plist keys from `INFOPLIST_KEY_*` build settings; rules_apple has no
equivalent, so BUILD files declare the keys as dicts and this writes them out as XML plists that
rules_apple merges (`infoplists`). Values can be strings, booleans, integers, lists and dicts.
"""

load("@bazel_skylib//rules:write_file.bzl", "write_file")

def info_plist(name, values, **kwargs):
    """Declares `<name>.plist` with the given keys.

    Args:
        name: target name; the output is `<name>.plist`.
        values: dict of Info.plist keys and values.
        **kwargs: common attributes such as `visibility` and `tags`.
    """
    write_file(
        name = name + "_json",
        out = name + ".plist.json",
        content = [json.encode_indent(values, indent = "  ")],
        **kwargs
    )

    # plutil ships with macOS and reads JSON; Apple builds only run on macOS anyway.
    native.genrule(
        name = name,
        srcs = [name + "_json"],
        outs = [name + ".plist"],
        cmd = "/usr/bin/plutil -convert xml1 -o $@ $<",
        **kwargs
    )
