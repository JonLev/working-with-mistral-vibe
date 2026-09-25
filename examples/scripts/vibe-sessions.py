#!/usr/bin/env python3
"""vibe-sessions — list, search and inspect Vibe session logs.

Vibe stores sessions under $VIBE_HOME/logs/session/ (default ~/.vibe/logs/session,
override with [session_logging] save_dir in config.toml). One directory per
session, named <prefix>_<YYYYMMDD_HHMMSS>_<shortid> (prefix defaults to
"session", short id = first 8 hex of the session UUID), containing meta.json
and messages.jsonl. A listing cache lives at .session_index.json (reconciled
against each meta.json mtime), and per-terminal pointers under
.last_session/<tty> drive `vibe -c`.

This tool reads that layout directly. It never writes anything.

Usage:
  vibe-sessions recent [N]              # N most recently updated (default 10)
  vibe-sessions search WORD [WORD ...]  # multi-word AND search over messages
  vibe-sessions info ID                 # partial short-id or session-id match
  vibe-sessions resume ID               # print the resume command (--exec to run it)
  vibe-sessions pointers                # per-TTY last-session pointers

Global flags:
  --json            machine-readable output
  --cwd DIR         only sessions that reach DIR (origin or working directory)
  --since 7d|2026-09-01   filter by start time
  --limit N         cap results (default 10 where applicable)

Zero dependencies: Python stdlib only.

Adapted from a session-history CLI in the source guide, re-derived for this
session layout — the source's per-project directory tree does not exist here.
"""

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path


def save_dir() -> Path:
    if os.environ.get("VIBE_SESSION_DIR"):
        return Path(os.environ["VIBE_SESSION_DIR"]).expanduser().resolve()
    home = Path(os.environ.get("VIBE_HOME", "~/.vibe")).expanduser().resolve()
    return home / "logs" / "session"


SESSION_DIR_RE = re.compile(r"^(?P<prefix>[a-z]+)_(?P<stamp>\d{8}_\d{6})_(?P<shortid>[0-9a-f]+)$")


def parse_since(value):
    m = re.fullmatch(r"(\d+)([smhd])", value)
    if m:
        delta = {"s": 1, "m": 60, "h": 3600, "d": 86400}[m.group(2)]
        return datetime.now(timezone.utc) - timedelta(seconds=int(m.group(1)) * delta)
    return datetime.fromisoformat(value).astimezone(timezone.utc)


def load_index(sdir: Path):
    f = sdir / ".session_index.json"
    if not f.is_file():
        return {}
    try:
        return json.loads(f.read_text())
    except json.JSONDecodeError:
        return {}  # corrupt index: rebuild from session dirs, like the CLI


def sessions(sdir: Path):
    """Yield one record per session dir, newest first. Index is used as a
    cache and reconciled against meta.json mtime, mirroring the CLI."""
    index = load_index(sdir)
    out = []
    for d in sdir.iterdir():
        if not d.is_dir() or not SESSION_DIR_RE.match(d.name):
            continue
        meta_f = d / "meta.json"
        if not meta_f.is_file():
            continue
        mtime = meta_f.stat().st_mtime_ns
        cached = index.get(d.name)
        meta = None
        if cached and cached.get("mtime_ns") == mtime:
            meta = dict(cached)
            meta["title"] = meta.get("title")
        else:
            try:
                meta = json.loads(meta_f.read_text())
            except (json.JSONDecodeError, OSError):
                meta = None
        if meta is None:
            continue
        out.append({
            "dir": d,
            "shortid": SESSION_DIR_RE.match(d.name).group("shortid"),
            "session_id": meta.get("session_id") or cached.get("session_id", ""),
            "title": meta.get("title"),
            "cwd": meta.get("environment", {}).get("working_directory") or cached.get("cwd", ""),
            "origin": meta.get("origin_directory") or cached.get("origin_directory", ""),
            "branch": meta.get("git_branch"),
            "start_time": meta.get("start_time"),
            "end_time": meta.get("end_time"),
            "total_messages": meta.get("total_messages"),
            "pinned_model": (meta.get("config") or {}).get("active_model"),
        })
    out.sort(key=lambda s: s["start_time"] or "", reverse=True)
    return out


def reaches(sess, cwd):
    return sess.get("cwd") == cwd or sess.get("origin") == cwd


def parse_start(sess):
    try:
        return datetime.fromisoformat(sess["start_time"]).astimezone(timezone.utc)
    except (TypeError, ValueError):
        return None


def find_by_id(sess_list, ident):
    ident = ident.lower()
    hits = [s for s in sess_list
            if s["shortid"].lower().startswith(ident) or s["session_id"].lower().startswith(ident)]
    return hits[0] if hits else None


def read_messages(sess):
    f = sess["dir"] / "messages.jsonl"
    if not f.is_file():
        return []
    out = []
    with f.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return out


def message_text(msg):
    parts = []
    if isinstance(msg.get("content"), str):
        parts.append(msg["content"])
    for tc in msg.get("tool_calls") or []:
        parts.append(tc.get("function", {}).get("arguments", ""))
    return " ".join(parts)


def human_row(sess):
    when = (sess["start_time"] or "")[:16].replace("T", " ")
    title = sess["title"] or "(no title)"
    loc = sess["cwd"] or sess["origin"] or "?"
    return f"{sess['shortid']}  {when}  {sess['session_id'][:8]}  {title[:48]:<48}  {loc}"


def cmd_recent(sess_list, args):
    rows = sess_list[:args.limit]
    if args.json:
        print(json.dumps(rows, indent=2, default=str))
        return 0
    for s in rows:
        print(human_row(s))
    print(f"{len(rows)} of {len(sess_list)} sessions "
          f"({save_dir()}); newest first; pass a count: recent 20")
    return 0


def cmd_search(sess_list, args):
    words = [w.lower() for w in args.keywords]
    hits = []
    for s in sess_list:
        match_line = None
        for msg in read_messages(s):
            text = message_text(msg).lower()
            if all(w in text for w in words):
                match_line = message_text(msg)
                break
        if match_line is not None:
            hits.append({"session": s, "preview": (match_line or "")[:160]})
            if len(hits) >= args.limit:
                break
    if args.json:
        print(json.dumps(hits, indent=2, default=str))
        return 0
    for h in hits:
        print(human_row(h["session"]))
        print(f"    {h['preview']}")
    print(f"{len(hits)} matching session(s)")
    return 0 if hits else 1


def cmd_info(sess_list, args):
    s = find_by_id(sess_list, args.session_id)
    if not s:
        print(f"no session matches '{args.session_id}'", file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps(s, indent=2, default=str))
        return 0
    for k in ("session_id", "shortid", "title", "branch", "start_time", "end_time",
              "cwd", "origin", "total_messages", "pinned_model"):
        print(f"{k:>16}: {s.get(k)}")
    print(f"           dir: {s['dir']}")
    print(f"       messages: {s['dir'] / 'messages.jsonl'}")
    return 0


def cmd_resume(sess_list, args):
    s = find_by_id(sess_list, args.session_id)
    if not s:
        print(f"no session matches '{args.session_id}'", file=sys.stderr)
        return 1
    cmd = ["vibe", "--resume", s["session_id"]]
    if args.json:
        print(json.dumps({"session_id": s["session_id"], "command": " ".join(cmd)}))
        return 0
    if args.exec_flag:
        os.execvp("vibe", cmd)
    print(" ".join(cmd))
    print("# --resume resolves by ID globally (no folder scoping); partial ids allowed")
    return 0


def cmd_pointers(_sess_list, args):
    pdir = save_dir() / ".last_session"
    if not pdir.is_dir():
        if args.json:
            print("{}")
        else:
            print(f"no pointer dir at {pdir} (created on first interactive session)")
        return 0
    pointers = {}
    for f in sorted(pdir.iterdir()):
        if f.is_file():
            pointers[f.name] = f.read_text().strip()
    if args.json:
        print(json.dumps(pointers, indent=2))
        return 0
    for tty, sid in pointers.items():
        print(f"{tty}: {sid}")
    return 0


def main():
    import argparse
    ap = argparse.ArgumentParser(description="List, search and inspect Vibe session logs")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    ap.add_argument("--cwd", help="only sessions reaching this directory (origin or working dir)")
    ap.add_argument("--since", help="only sessions started since: 7d, 12h, or ISO date")
    ap.add_argument("--limit", type=int, default=10)
    sub = ap.add_subparsers(dest="cmd")

    p = sub.add_parser("recent", help="most recently started sessions")
    p.add_argument("count", nargs="?", type=int)

    p = sub.add_parser("search", help="multi-word AND search over messages")
    p.add_argument("keywords", nargs="+")

    p = sub.add_parser("info", help="session details (partial id match)")
    p.add_argument("session_id")

    p = sub.add_parser("resume", help="print the resume command")
    p.add_argument("session_id")
    p.add_argument("--exec", dest="exec_flag", action="store_true", help="run it")

    sub.add_parser("pointers", help="per-TTY last-session pointers")

    args = ap.parse_args()
    if args.cmd is None:
        args.cmd = "recent"
    if args.cmd == "recent" and args.count:
        args.limit = args.count

    sdir = save_dir()
    if not sdir.is_dir():
        print(f"no session store at {sdir}", file=sys.stderr)
        return 1
    sess_list = sessions(sdir)
    if args.cwd:
        cwd = str(Path(args.cwd).resolve())
        sess_list = [s for s in sess_list if reaches(s, cwd)]
    if args.since:
        cutoff = parse_since(args.since)
        sess_list = [s for s in sess_list
                     if (parse_start(s) or datetime.min.replace(tzinfo=timezone.utc)) >= cutoff]

    return {"recent": cmd_recent, "search": cmd_search, "info": cmd_info,
            "resume": cmd_resume, "pointers": cmd_pointers}[args.cmd](sess_list, args)


if __name__ == "__main__":
    sys.exit(main())
