"""yamlmini -- stdlib-only YAML subset parser for this repo.

Python's stdlib has no YAML module and this repo deliberately avoids
third-party dependencies, so frontmatter and quiz files are constrained to
the subset parsed here:

- mappings and nested mappings (indentation-based)
- lists ("- item" scalars and "- key: value" list items)
- inline flow lists ([a, b, c])
- block scalars ("key: |" literal blocks)
- single/double-quoted and bare scalars
- full-line comments and trailing " #" comments on scalar values

Anything else raises YamlMiniError. Callers must fail loudly on it.
"""

from __future__ import annotations

import re


class YamlMiniError(ValueError):
    pass


_KEY_RE = re.compile(r"^([^:\s][^:]*):(?:\s+(.*))?$")
_BULLET_RE = re.compile(r"^-(?:\s+(.*))?$")


def _unquote(s):
    s = s.strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in ("'", '"'):
        inner = s[1:-1]
        if s[0] == '"':
            return inner.replace('\\"', '"')
        return inner.replace("''", "'")
    return s


def _strip_inline_comment(s):
    """Drop a trailing ' # ...' comment that is outside quotes."""
    quote = None
    for i, ch in enumerate(s):
        if quote:
            if ch == quote:
                quote = None
        elif ch in ('"', "'"):
            quote = ch
        elif ch == "#":
            if i > 0 and s[i - 1] in " \t":
                return s[:i].rstrip()
    return s


def _split_flow(inner):
    parts, buf, quote = [], "", None
    for ch in inner:
        if quote:
            buf += ch
            if ch == quote:
                quote = None
        elif ch in ('"', "'"):
            quote = ch
            buf += ch
        elif ch == ",":
            parts.append(buf)
            buf = ""
        else:
            buf += ch
    parts.append(buf)
    return [p.strip() for p in parts if p.strip()]


def _flow_list(s):
    s = s.strip()
    if not (s.startswith("[") and s.endswith("]")):
        raise YamlMiniError(f"not a flow list: {s!r}")
    inner = s[1:-1].strip()
    if not inner:
        return []
    return [_unquote(p) for p in _split_flow(inner)]


def _scalar(raw):
    raw = _strip_inline_comment(raw)
    if raw.startswith("["):
        return _flow_list(raw)
    return _unquote(raw)


class _Parser:
    def __init__(self, text, source="<yaml>"):
        self.lines = text.splitlines()
        self.source = source

    def err(self, lineno, msg):
        return YamlMiniError(f"{self.source}:{lineno}: {msg}")

    def next_content(self, i):
        while i < len(self.lines):
            stripped = self.lines[i].strip()
            if stripped and not stripped.startswith("#"):
                return i
            i += 1
        return None

    def indent_of(self, i):
        raw = self.lines[i]
        return len(raw) - len(raw.lstrip(" "))

    def parse_block(self, i, min_indent):
        """Parse the block whose first content line is at/after i (>= min_indent)."""
        first = self.next_content(i)
        if first is None:
            raise self.err(i + 1, "expected content, found end of input")
        indent = self.indent_of(first)
        if indent < min_indent:
            raise self.err(first + 1, f"expected indent >= {min_indent}, found {indent}")
        content = self.lines[first].strip()
        if _BULLET_RE.match(content):
            return self.parse_list(first, indent)
        return self.parse_map(first, indent)

    def parse_map(self, i, indent):
        result = {}
        n = i
        while True:
            n = self.next_content(n)
            if n is None:
                return result, len(self.lines)
            cur_indent = self.indent_of(n)
            content = self.lines[n].strip()
            if cur_indent < indent:
                return result, n
            if cur_indent > indent:
                raise self.err(n + 1, f"unexpected indent {cur_indent}, expected {indent}")
            if _BULLET_RE.match(content):
                raise self.err(n + 1, "unexpected list item inside a mapping")
            m = _KEY_RE.match(content)
            if not m:
                raise self.err(n + 1, f"expected 'key: value', found {content!r}")
            key = _unquote(m.group(1))
            rest = m.group(2)
            if rest is None or rest.strip() in ("", "|", "|-", "|+", ">", ">-", ">+"):
                if rest is not None and rest.strip().startswith(("|", ">")):
                    value, n = self.parse_block_scalar(n, indent, rest.strip())
                    result[key] = value
                    continue
                # empty value: nested block (mapping or list) or null
                nxt = self.next_content(n + 1)
                if nxt is None or self.indent_of(nxt) <= indent:
                    result[key] = None
                    n += 1
                    continue
                value, n = self.parse_block(n + 1, indent + 1)
                result[key] = value
                continue
            result[key] = _scalar(rest)
            n += 1

    def parse_block_scalar(self, i, indent, style):
        collected = []
        base = None
        n = i + 1
        while n < len(self.lines):
            raw = self.lines[n]
            if raw.strip() == "":
                collected.append("")
                n += 1
                continue
            ind = len(raw) - len(raw.lstrip(" "))
            if ind <= indent:
                break
            if base is None:
                base = ind
            if ind < base:
                break
            collected.append(raw[base:])
            n += 1
        while collected and collected[-1] == "":
            collected.pop()
        text = "\n".join(collected)
        if style.startswith("|") and not style.endswith("-"):
            text += "\n"
        return text, n

    def parse_list(self, i, indent):
        items = []
        n = i
        while True:
            n = self.next_content(n)
            if n is None:
                return items, len(self.lines)
            cur_indent = self.indent_of(n)
            content = self.lines[n].strip()
            if cur_indent < indent or not _BULLET_RE.match(content):
                if cur_indent > indent:
                    raise self.err(n + 1, f"unexpected indent {cur_indent} in list")
                return items, n
            rest = _BULLET_RE.match(content).group(1)
            if rest is None:
                value, n = self.parse_block(n + 1, indent + 1)
                items.append(value)
                continue
            m = _KEY_RE.match(rest)
            if m:
                # first pair of an inline mapping; continuation lines follow
                item = {_unquote(m.group(1)): _scalar(m.group(2)) if m.group(2) else None}
                if m.group(2) is None or m.group(2).strip() in ("", "|", "|-", "|+", ">", ">-", ">+"):
                    key = _unquote(m.group(1))
                    nxt = self.next_content(n + 1)
                    if (
                        m.group(2) is not None
                        and m.group(2).strip().startswith(("|", ">"))
                    ):
                        value, n = self.parse_block_scalar(n, indent + 2, m.group(2).strip())
                        item[key] = value
                    elif nxt is None or self.indent_of(nxt) <= indent + 1:
                        item[key] = None
                        n += 1
                    else:
                        value, n = self.parse_block(n + 1, indent + 2)
                        item[key] = value
                items.append(item)
                value, n = self.parse_map(n + 1, indent + 2)
                item.update(value)
                continue
            items.append(_scalar(rest))
            n += 1


def parse(text, source="<yaml>"):
    """Parse a YAML-subset document into Python objects."""
    parser = _Parser(text, source)
    first = parser.next_content(0)
    if first is None:
        return {}
    value, n = parser.parse_block(0, 0)
    rest = parser.next_content(n if n is not None else len(parser.lines))
    if rest is not None:
        raise parser.err(rest + 1, "unexpected trailing content")
    return value


def parse_frontmatter(text, source="<input>"):
    """Split '---' frontmatter from a markdown page.

    Returns (mapping, body, offset): body is the markdown after the closing
    '---', and offset is the number of file lines consumed before it, so
    that a body line N corresponds to file line N + offset.
    """
    if not text.startswith("---"):
        raise YamlMiniError(f"{source}: expected '---' on the first line")
    lines = text.splitlines()
    end = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            end = idx
            break
    if end is None:
        raise YamlMiniError(f"{source}: unterminated frontmatter block")
    fm = parse("\n".join(lines[1:end]), source)
    if not isinstance(fm, dict):
        raise YamlMiniError(f"{source}: frontmatter must be a mapping")
    body = "\n".join(lines[end + 1:])
    return fm, body, end + 1
