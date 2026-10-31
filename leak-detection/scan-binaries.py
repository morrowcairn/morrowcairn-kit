#!/usr/bin/env python3
#
# scan-binaries.py — clears, or refuses, every binary file a push adds. pre-push runs it for each
# pushed ref whose new commits add or change a binary file, and whose tip turns the scan on (a tracked
# kit.binaries holding scan=on, or a tracked reviewed list), and only then: python3 is needed for
# pushes that carry a binary in such a project, and for nothing else.
#
#   python3 leak-detection/scan-binaries.py TIP [--not KNOWN...]    (the range pre-push computed)
#
# gitleaks cannot read binary content, and the identity layer reads only raw bytes at the tip, so
# a binary needs its own check. Measured before this was written: a marker in a PNG's compressed
# text chunk or in UTF-16 passed the identity layer, and gitleaks' directory scan skipped a .png
# by its extension even with a credential stored in plain text inside it. Every binary blob added
# by any commit in the range, not just at the tip, is cleared only if ALL of these hold:
#
#   1. REVIEWED. Its full blob id is on the reviewed list, records/reviewed_binaries.txt, read from
#      the pushed TIP's tree -- never from the working tree, which a push does not send. A blob id
#      names exact bytes: a copy or a rename of reviewed bytes needs no new review, and any change
#      to them, however small, does. A list by path would clear whatever bytes land at that path
#      next -- a regenerated image, a replaced favicon -- unreviewed. The review is a person's: the
#      pixels themselves can show what no scan can read.
#   2. STRUCTURALLY PLAIN. PNG, JPEG and WebP only, holding only chunk types that have no metadata
#      field -- the places tools write authors, software, GPS, paths, comments. Refused by type name:
#      metadata (text, EXIF, XMP, colour profiles, time, comments, thumbnails, any JPEG APPn but the
#      plain JFIF header), bytes after the image's end, any unknown chunk type, any other format.
#      An allowed chunk still holds bytes (a palette holds up to 768, the pixel data any number);
#      whatever text they hold is the strings pass's to catch, below. The fix for a refusal is to
#      re-encode or strip. WebP keeps the set its spawn images were measured to use.
#      Video, MP4 (H.264) and WebM (VP9), keeps the set its spawn's clean encodes were measured to
#      use, each box or element only inside its named parent, with text fields checked by value
#      (section 2, video, below). Refused by name: uuid boxes, metadata items, attachments, chapters,
#      titles, dates, audio, any unknown box or element, and bytes after the end.
#   3. NO MATCH IN ITS STRINGS. The raw bytes and their UTF-16 text are matched against LEAK_PATTERN
#      with the identity layer's engine (git grep -iE), and the printable strings go through gitleaks,
#      always with a named config: the clone's .gitleaks.toml, or else the spawn rules beside this file.
#      Given none, gitleaks takes one from GITLEAKS_CONFIG or GITLEAKS_CONFIG_TOML, so the caller's
#      environment would choose the rules (gates procedure 13, item 1; hooks_test BC1 to BC4).
#
# Exit 0 = every binary cleared; 1 = at least one refused (each named, with its reasons); 2 = the
# scan could not run. Nothing it prints quotes a blob's content or the pattern, nor a path the list matches.
#
import os
import re
import struct
import subprocess
import sys
import tempfile

# Text handling runs byte-wise, matching in the caller's locale, as in pre-push: every
# git and gitleaks this scan starts runs under LC_ALL=C, but each git grep runs in the locale pre-push saved and hands
# on (KIT_CALLER_LOCALE), or this process's own when none is handed on (install test LG1).
CALLER_LOCALE = (os.environ.get("KIT_CALLER_LOCALE") or os.environ.get("LC_ALL") or os.environ.get("LC_CTYPE")
                 or os.environ.get("LANG") or "C")
CALLER_ENV = dict(os.environ, LC_ALL=CALLER_LOCALE)
os.environ["LC_ALL"] = "C"

LIST = "records/reviewed_binaries.txt"
SPAWN_RULES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "spawn.gitleaks.toml")
GITLEAKS_ENV = {k: v for k, v in os.environ.items() if k not in ("GITLEAKS_CONFIG", "GITLEAKS_CONFIG_TOML")}


class ScanError(Exception):
    pass


def git(*args):
    r = subprocess.run(["git", *args], capture_output=True)
    if r.returncode != 0:
        raise ScanError(f"git {args[0]} exited {r.returncode}")
    return r.stdout


# ---- 2. structure: only chunk types with no metadata field --------------------------------------
# PNG: the image header, pixel data and end; palette and transparency; and the colour and pixel-size
# chunks, whose fields are fixed-size numbers.
PNG_OK = {b"IHDR", b"IDAT", b"IEND", b"PLTE", b"tRNS", b"gAMA", b"cHRM", b"sBIT", b"bKGD", b"hIST",
          b"pHYs", b"sRGB"}
WEBP_OK = {b"VP8X", b"ALPH", b"VP8 "}
# JPEG: every frame header (SOF0-3, 5-7, 9-11, 13-15), quantisation and Huffman tables, the restart
# interval, and scan headers; restart markers inside the scan data. APP0 is allowed only as the
# 16-byte JFIF header, which leaves no room for a thumbnail.
JPEG_OK = {0xDB, 0xC4, 0xDD, 0xDA} | {m for m in range(0xC0, 0xD0) if m not in (0xC4, 0xC8, 0xCC)}


def png(b):
    problems, i, seen_end = [], 8, False
    while i < len(b):
        if seen_end:
            return problems + [f"has {len(b) - i} byte(s) after its end (IEND)"]
        if i + 12 > len(b):
            return problems + ["could not be parsed: a chunk runs past the end of the file"]
        n, t = struct.unpack(">I4s", b[i:i + 8])
        if i + 12 + n > len(b):
            return problems + ["could not be parsed: a chunk runs past the end of the file"]
        if t not in PNG_OK:
            problems.append(f"carries a {t.decode('latin1')!r} chunk")
        seen_end = t == b"IEND"
        i += 12 + n
    return problems if seen_end else problems + ["could not be parsed: no IEND chunk"]


def webp(b):
    problems = []
    size = struct.unpack("<I", b[4:8])[0]
    if size + 8 < len(b):
        problems.append(f"has {len(b) - size - 8} byte(s) after its end (the RIFF size)")
    elif size + 8 > len(b):
        return ["could not be parsed: the RIFF size runs past the end of the file"]
    i, end = 12, size + 8
    while i < end:
        if i + 8 > end:
            return problems + ["could not be parsed: a chunk runs past the RIFF size"]
        t, n = struct.unpack("<4sI", b[i:i + 8])
        if i + 8 + n > end:
            return problems + ["could not be parsed: a chunk runs past the RIFF size"]
        if t not in WEBP_OK:
            problems.append(f"carries a {t.decode('latin1')!r} chunk")
        i += 8 + n + (n & 1)
    return problems


def jpeg_name(m):
    if m == 0xFE:
        return "COM"
    if 0xE0 <= m <= 0xEF:
        return f"APP{m - 0xE0}"
    if 0xC0 <= m <= 0xCF and m not in (0xC4, 0xC8, 0xCC):
        return f"SOF{m - 0xC0}"
    return {0xCC: "DAC", 0xDD: "DRI"}.get(m, f"0xFF{m:02X}")


def jpeg(b):
    problems, i = [], 2
    while True:
        while i < len(b) and b[i] == 0xFF and i + 1 < len(b) and b[i + 1] == 0xFF:
            i += 1                                    # fill bytes before a marker are allowed
        if i + 2 > len(b) or b[i] != 0xFF:
            return problems + ["could not be parsed: a segment does not start with a marker"]
        m = b[i + 1]
        if m == 0xD9:                                 # EOI
            i += 2
            break
        if i + 4 > len(b):
            return problems + ["could not be parsed: a segment runs past the end of the file"]
        n = struct.unpack(">H", b[i + 2:i + 4])[0]
        if n < 2 or i + 2 + n > len(b):
            return problems + ["could not be parsed: a segment runs past the end of the file"]
        if m == 0xE0:
            if not (n == 16 and b[i + 4:i + 9] == b"JFIF\x00"):
                problems.append("carries an APP0 segment other than the plain 16-byte JFIF header")
        elif m not in JPEG_OK:
            problems.append(f"carries a {jpeg_name(m)!r} segment")
        i += 2 + n
        if m == 0xDA:                                 # entropy-coded data runs to the next marker that
            while i + 1 < len(b) and not (b[i] == 0xFF and b[i + 1] != 0x00   # is not a stuffed 0xFF
                                          and not 0xD0 <= b[i + 1] <= 0xD7):  # or a restart (RSTn)
                i += 1
    if i < len(b):
        problems.append(f"has {len(b) - i} byte(s) after its end (EOI)")
    return problems


# ---- 2, video: MP4 and WebM, by a named allowlist of container structure ------------------------
# The structure the spawns' clean encodes were measured to use: one video track, H.264 in MP4 and VP9
# in WebM, no audio. Each box or element is allowed only inside a named parent; anything else is
# refused by name without being read -- a uuid box, where a tool's raw download carries its provenance
# manifest, an ilst item, an attachment, a chapter, a title. The frame data (mdat, SimpleBlock) is
# not parsed: like a PNG's IDAT, whatever text it holds is the strings pass's.
#
# Text fields are checked by value and never quoted. The encoder writes a few of its own, which are
# admitted by exact value (the bit-exact forms, with no version) rather than required absent: WebM
# requires MuxingApp and WritingApp, so they cannot be encoded away. Numeric fields are left to the
# strings pass, as a PNG palette is, except the MP4 times, which must be zero.
class Unparsable(Exception):
    pass


def fourcc(t):
    return "'" + "".join(chr(c) if 0x20 <= c < 0x7F else f"\\x{c:02x}" for c in t) + "'"


MP4_BOXES = {   # parent -> the boxes allowed directly inside it; a box listed as a parent is walked
    None:   {b"ftyp", b"moov", b"free", b"mdat"},
    b"moov": {b"mvhd", b"trak", b"udta"},
    b"trak": {b"tkhd", b"edts", b"mdia"},
    b"edts": {b"elst"},
    b"mdia": {b"mdhd", b"hdlr", b"minf"},
    b"minf": {b"vmhd", b"dinf", b"stbl"},
    b"dinf": {b"dref"},
    b"dref": {b"url "},
    b"stbl": {b"stsd", b"stts", b"stss", b"ctts", b"stsc", b"stsz", b"stco"},
    b"stsd": {b"avc1"},
    b"avc1": {b"avcC", b"colr", b"btrt"},
    b"udta": {b"meta"},
    b"meta": {b"hdlr", b"ilst"},
    b"ilst": set(),                                   # the empty holder: any metadata item in it is refused
}
MP4_SKIP = {b"dref": 8, b"stsd": 8, b"meta": 4, b"avc1": 78}   # fields before a parent's child boxes
# At most one of each: a second track is shown by no player, so the person reviewing never sees it.
MP4_ONCE = {b"moov", b"trak"}
MP4_BRANDS = {b"isom", b"iso2", b"avc1", b"mp41"}
# (parent, handler type, the 12 reserved bytes) -> the handler names allowed; empty is always allowed.
MP4_HANDLERS = {(b"mdia", b"vide", bytes(12)): {b"VideoHandler"},
                (b"meta", b"mdir", b"appl" + bytes(8)): set()}
MP4_COMPRESSORS = {b"Lavc libx264"}


def mp4_box(t, body, parent):
    if t == b"ftyp":
        brands = [body[0:4]] + [body[k:k + 4] for k in range(8, len(body), 4)]
        if len(body) < 8 or len(body) % 4 or any(x not in MP4_BRANDS for x in brands):
            return ["has a file-type brand that is not on the allowed list"]
    elif t in (b"mvhd", b"tkhd", b"mdhd"):            # version 1 widens the two times from 4 bytes to 8
        times = body[4:20] if body[:1] == b"\x01" else body[4:12]
        if len(times) < 8 or any(times):
            return [f"has a creation or modification time in its {fourcc(t)} box"]
    elif t == b"hdlr":
        name = body[24:]
        name = name[:-1] if name.endswith(b"\0") else name
        allowed = MP4_HANDLERS.get((parent, body[8:12], body[12:24]))
        if allowed is None:
            return ["has a handler type that is not on the allowed list"]
        if name and name not in allowed:
            return ["has a handler name that is not on the allowed list"]
    elif t == b"avc1":                                # compressor name: a length byte, then 31 bytes
        field = body[42:74]
        n = field[0] if field else 0
        if len(field) < 32 or n > 31 or (n and field[1:1 + n] not in MP4_COMPRESSORS):
            return ["has a compressor name that is not on the allowed list"]
        if any(field[1 + n:]):
            return ["has bytes after its compressor name"]
    elif t == b"url ":                                # flag 1: the data is in this file, and no location follows
        if body != b"\x00\x00\x00\x01":
            return ["has a data reference to a location outside the file"]
    elif t == b"colr":
        if body[:4] != b"nclx" or len(body) != 11:
            return ["has a 'colr' box other than the plain 'nclx' colour type"]
    elif t == b"free":
        if any(body):
            return ["has a 'free' box that is not all zero bytes"]
    return []


def mp4_walk(b, i, end, parent, problems):
    seen = set()
    while i < end:
        if end - i < 8:
            if parent is None:
                problems.append(f"has {end - i} byte(s) after its last box")
                return
            raise Unparsable(f"a box header runs past the end of its {fourcc(parent)} box")
        n, t = struct.unpack(">I4s", b[i:i + 8])
        head = 8
        if n == 1:
            if end - i < 16:
                raise Unparsable("a box header runs past the end of the file")
            n, head = struct.unpack(">Q", b[i + 8:i + 16])[0], 16
        elif n == 0 and parent is None:
            n = end - i                               # the last box runs to the end of the file
        if n < head + MP4_SKIP.get(t, 0) or i + n > end:
            raise Unparsable(f"a {fourcc(t)} box runs past the end of its parent")
        if t not in MP4_BOXES[parent]:
            where = f" in {fourcc(parent)}" if parent else ""
            problems.append(f"carries a {fourcc(t)} box{where}")
        else:
            if t in MP4_ONCE and t in seen:
                problems.append(f"has more than one {fourcc(t)} box in {fourcc(parent) if parent else 'the file'}")
            seen.add(t)
            problems += mp4_box(t, b[i + head:i + n], parent)
            if t in MP4_BOXES:
                mp4_walk(b, i + head + MP4_SKIP.get(t, 0), i + n, t, problems)
        i += n


def mp4(b):
    problems = []
    try:
        mp4_walk(b, 0, len(b), None, problems)
    except Unparsable as e:
        problems.append(f"could not be parsed: {e}")
    return problems


# WebM: parent -> {child ID: (name, kind)}. Kinds: m, a master element, walked; u, an unsigned number
# (at most 8 bytes); f, a float (0, 4 or 8 bytes); s, text, checked against WEBM_TEXT; b, frame data;
# z, padding, all zero bytes. A SimpleTag's name and value are checked as a pair against WEBM_TAGS.
EBML, SEGMENT, SIMPLETAG = 0x1A45DFA3, 0x18538067, 0x67C8
WEBM = {
    None:       {EBML: ("EBML", "m"), SEGMENT: ("Segment", "m")},
    EBML:       {0x4286: ("EBMLVersion", "u"), 0x42F7: ("EBMLReadVersion", "u"), 0x42F2: ("EBMLMaxIDLength", "u"),
                 0x42F3: ("EBMLMaxSizeLength", "u"), 0x4282: ("DocType", "s"), 0x4287: ("DocTypeVersion", "u"),
                 0x4285: ("DocTypeReadVersion", "u")},
    SEGMENT:    {0x114D9B74: ("SeekHead", "m"), 0xEC: ("Void", "z"), 0x1549A966: ("Info", "m"),
                 0x1654AE6B: ("Tracks", "m"), 0x1254C367: ("Tags", "m"), 0x1F43B675: ("Cluster", "m"),
                 0x1C53BB6B: ("Cues", "m")},
    0x114D9B74: {0x4DBB: ("Seek", "m")},
    0x4DBB:     {0x53AB: ("SeekID", "u"), 0x53AC: ("SeekPosition", "u")},
    0x1549A966: {0x2AD7B1: ("TimestampScale", "u"), 0x4D80: ("MuxingApp", "s"), 0x5741: ("WritingApp", "s"),
                 0x4489: ("Duration", "f")},
    0x1654AE6B: {0xAE: ("TrackEntry", "m")},
    0xAE:       {0xD7: ("TrackNumber", "u"), 0x73C5: ("TrackUID", "u"), 0x9C: ("FlagLacing", "u"),
                 0x22B59C: ("Language", "s"), 0x86: ("CodecID", "s"), 0x83: ("TrackType", "u"),
                 0x23E383: ("DefaultDuration", "u"), 0xE0: ("Video", "m")},
    0xE0:       {0xB0: ("PixelWidth", "u"), 0xBA: ("PixelHeight", "u"), 0x9A: ("FlagInterlaced", "u"),
                 0x55B0: ("Colour", "m")},
    0x55B0:     {0x55B1: ("MatrixCoefficients", "u"), 0x55B7: ("ChromaSitingHorz", "u"),
                 0x55B8: ("ChromaSitingVert", "u"), 0x55B9: ("Range", "u"), 0x55BA: ("TransferCharacteristics", "u"),
                 0x55BB: ("Primaries", "u")},
    0x1254C367: {0x7373: ("Tag", "m")},
    0x7373:     {0x63C0: ("Targets", "m"), SIMPLETAG: ("SimpleTag", "m")},
    0x63C0:     {0x63C5: ("TagTrackUID", "u")},
    SIMPLETAG:  {0x45A3: ("TagName", "s"), 0x4487: ("TagString", "s")},
    0x1F43B675: {0xE7: ("Timestamp", "u"), 0xA3: ("SimpleBlock", "b")},
    0x1C53BB6B: {0xBB: ("CuePoint", "m")},
    0xBB:       {0xB3: ("CueTime", "u"), 0xB7: ("CueTrackPositions", "m")},
    0xB7:       {0xF7: ("CueTrack", "u"), 0xF1: ("CueClusterPosition", "u"), 0xF0: ("CueRelativePosition", "u")},
}
WEBM_ONCE = {"Tracks", "TrackEntry"}               # one video track, as MP4_ONCE
WEBM_NAMES = {pid: name for kids in WEBM.values() for pid, (name, _) in kids.items()}
WEBM_NAMES.update({0x1941A469: "Attachments", 0x1043A770: "Chapters", 0x7BA9: "Title", 0x4461: "DateUTC",
                   0x73A4: "SegmentUUID", 0x536E: "Name", 0xE1: "Audio", 0x63A2: "CodecPrivate", 0xA0: "BlockGroup",
                   0xBF: "CRC-32", 0x447A: "TagLanguage", 0x4485: "TagBinary", 0x4484: "TagDefault"})
WEBM_TEXT = {"DocType": {b"webm"}, "MuxingApp": {b"Lavf"}, "WritingApp": {b"Lavf"}, "Language": {b"und"},
             "CodecID": {b"V_VP9"}}
WEBM_TAGS = {b"ENCODER": re.compile(rb"Lavc libvpx-vp9"), b"DURATION": re.compile(rb"[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{9}")}


def vint(b, i, end, what):                            # -> (length, value with the length marker removed)
    if i >= end or b[i] == 0:
        raise Unparsable(f"an element {what} runs past its parent or is longer than 8 bytes")
    n = 9 - b[i].bit_length()
    if i + n > end:
        raise Unparsable(f"an element {what} runs past its parent")
    return n, int.from_bytes(b[i:i + n], "big") & ((1 << (7 * n)) - 1)


def webm_walk(b, i, end, parent, problems):
    tag, seen = {}, set()                             # a SimpleTag's TagName and TagString values
    while i < end:
        n_id, _ = vint(b, i, end, "ID")
        if n_id > 4:
            raise Unparsable("an element ID is longer than 4 bytes")
        eid = int.from_bytes(b[i:i + n_id], "big")
        n_size, size = vint(b, i + n_id, end, "size")
        if size == (1 << (7 * n_size)) - 1:
            raise Unparsable("an element of unknown size (a live-stream form this scan does not read)")
        start = i + n_id + n_size
        if start + size > end:
            raise Unparsable("an element runs past the end of its parent")
        body, i = b[start:start + size], start + size
        where = f" in {WEBM_NAMES[parent]!r}" if parent else ""
        if eid not in WEBM[parent]:
            name = WEBM_NAMES.get(eid)
            problems.append(f"carries {'an' if name[0] in 'AEIOU' else 'a'} {name!r} element{where}" if name
                            else f"carries an element with ID 0x{eid:X}{where}")
            continue
        name, kind = WEBM[parent][eid]
        if name in WEBM_ONCE and name in seen:
            problems.append(f"has more than one {name!r} element{where}")
        seen.add(name)
        if kind == "m":
            webm_walk(b, start, start + size, eid, problems)
        elif (kind == "u" and size > 8) or (kind == "f" and size not in (0, 4, 8)):
            problems.append(f"has a {name!r} element longer than a number")
        elif kind == "z" and any(body):
            problems.append(f"has a {name!r} element that is not all zero bytes")
        elif kind == "s":
            value = body.rstrip(b"\0")                # text may be padded with zero bytes, and only at its end
            if parent == SIMPLETAG:
                tag.setdefault(name, []).append(value)
            elif value not in WEBM_TEXT[name]:
                problems.append(f"has a {name!r} value that is not on the allowed list")
        if parent is None and eid == SEGMENT and i < end:
            problems.append(f"has {end - i} byte(s) after its end (the Segment size)")
            return
    if parent == SIMPLETAG:                           # exactly one name and one value, and the pair allowed
        names, values = tag.get("TagName", []), tag.get("TagString", [])
        rule = WEBM_TAGS.get(names[0]) if len(names) == 1 else None
        if rule is None or len(values) != 1 or not rule.fullmatch(values[0]):
            problems.append("has a tag that is not on the allowed list")


def webm(b):
    problems = []
    try:
        webm_walk(b, 0, len(b), None, problems)
    except Unparsable as e:
        problems.append(f"could not be parsed: {e}")
    return problems


def structure(b):
    if b[:8] == b"\x89PNG\r\n\x1a\n":
        return png(b)
    if b[:2] == b"\xff\xd8":
        return jpeg(b)
    if len(b) >= 12 and b[:4] == b"RIFF" and b[8:12] == b"WEBP":
        return webp(b)
    if len(b) >= 8 and b[4:8] == b"ftyp":
        return list(dict.fromkeys(mp4(b)))            # each reason once, however many boxes carry it
    if b[:4] == b"\x1a\x45\xdf\xa3":
        return list(dict.fromkeys(webm(b)))
    return ["is not a format this scan can read (PNG, JPEG, WebP, MP4, WebM)"]


# ---- 3. strings: LEAK_PATTERN on the bytes and their UTF-16 text; gitleaks on printable runs ---
def strings(b):
    ascii_runs = re.findall(rb"[\x20-\x7e\t]{8,}", b)
    utf16 = [r.decode("utf-16-le").encode() for r in re.findall(rb"(?:[\x20-\x7e]\x00){4,}", b)]
    return ascii_runs, utf16


def string_problems(b, pattern, gitleaks_cfg):
    problems = []
    ascii_runs, utf16 = strings(b)
    with tempfile.TemporaryDirectory() as d:
        with open(os.path.join(d, "raw"), "wb") as f:
            f.write(b)
        with open(os.path.join(d, "utf16"), "wb") as f:
            f.write(b"\n".join(utf16) + b"\n")
        # git grep --no-index: 0 = a match, 1 = none, anything else = it did not run. Its stderr is
        # never printed: for a pattern that fails to compile, git quotes the pattern back.
        r = subprocess.run(["git", "grep", "--no-color", "--no-index", "-q", "-a", "-i", "-E", "-e", pattern,
                            "--", "raw", "utf16"], env=CALLER_ENV, cwd=d, capture_output=True)
        if r.returncode == 0:
            problems.append("matches LEAK_PATTERN in its bytes or UTF-16 text")
        elif r.returncode != 1:
            raise ScanError(f"the LEAK_PATTERN match did not run (git grep exit {r.returncode})")
    r = subprocess.run(["gitleaks", "stdin", "--no-banner", "--no-color", "--redact",
                        "--exit-code", "3", *gitleaks_cfg],
                       input=b"\n".join(ascii_runs + utf16) + b"\n", env=GITLEAKS_ENV, capture_output=True)
    if r.returncode == 3:
        problems.append("has credential shapes in its strings (gitleaks)")
    elif r.returncode != 0:
        raise ScanError(f"gitleaks did not complete (exit {r.returncode})")
    return problems


# ---- 1. the reviewed list, read from the pushed tip ---------------------------------------------
def reviewed(tip):
    if not git("ls-tree", tip, "--", LIST).strip():
        return set()
    width = 64 if git("rev-parse", "--show-object-format").strip() == b"sha256" else 40
    ids = set()
    for n, line in enumerate(git("cat-file", "blob", f"{tip}:{LIST}").decode("utf-8", "replace").splitlines(), 1):
        fields = line.split()
        if not fields or fields[0].startswith("#"):
            continue
        if len(fields) < 2 or not re.fullmatch(rf"[0-9a-f]{{{width}}}", fields[0]):
            raise ScanError(f"line {n} of {LIST} at {tip[:12]} is not '<full {width}-character blob id> <note>'")
        ids.add(fields[0])
    return ids


def binary_blobs(rng):
    blobs = {}                                        # blob id -> the first path it was added at
    # A merge is read against its first parent, as pre-push's count and gitleaks read it: that diff holds every binary
    # the merge adds that neither parent has (hooks_test MG5).
    for c in git("rev-list", *rng).decode().split():
        parents = git("rev-list", "--parents", "-n", "1", c).decode().split()[1:]
        against = [parents[0], c] if len(parents) > 1 else ["--root", c]
        out = git("diff-tree", "-r", "--no-renames", "--no-commit-id", "-z", "--numstat",
                  "--diff-filter=ACMT", *against)
        for rec in out.split(b"\0"):
            if rec.startswith(b"-\t-\t"):
                path = rec[4:]
                blob = git("rev-parse", f"{c}:{os.fsdecode(path)}").decode().strip()
                blobs.setdefault(blob, os.fsdecode(path))
    return blobs


def withheld(paths, pattern):
    """The paths not to print: those the list matches, by the same matcher in the caller's locale, as pre-push's own
    naming withholds a file name. A path holding a newline is withheld, and a match that
    can't run withholds every path: nothing unchecked is printed. git grep asks for no colour: with colour forced in a
    config file its lines missed the parse below, and a path the list matches was printed (hooks_test BW1b)."""
    hide = {p for p in paths if "\n" in p}
    safe = [p for p in paths if "\n" not in p]
    if not safe:
        return hide
    with tempfile.TemporaryDirectory() as d:
        with open(os.path.join(d, "names"), "wb") as f:
            f.write(b"".join(os.fsencode(p) + b"\n" for p in safe))
        r = subprocess.run(["git", "grep", "--no-color", "--no-index", "-n", "-a", "-i", "-E", "-e", pattern, "--", "names"],
                           env=CALLER_ENV, cwd=d, capture_output=True)
    if r.returncode == 1:
        return hide
    if r.returncode != 0:
        return hide | set(safe)
    for line in r.stdout.split(b"\n"):
        parts = line.split(b":", 2)
        if len(parts) == 3 and parts[0] == b"names" and parts[1].isdigit() and 0 < int(parts[1]) <= len(safe):
            hide.add(safe[int(parts[1]) - 1])
    return hide


def main(rng):
    pattern = os.environ.get("LEAK_PATTERN", "")
    if not pattern:
        raise ScanError("LEAK_PATTERN is not set")
    if os.path.isfile(".gitleaks.toml"):
        cfg = ["--config", ".gitleaks.toml"]
    elif os.path.isfile(SPAWN_RULES):
        cfg = ["--config", SPAWN_RULES]
    else:
        raise ScanError("the clone has no .gitleaks.toml and spawn.gitleaks.toml is not beside the scan, so it has "
                        "no credential rules of its own; reinstall the release, or add the project's .gitleaks.toml")
    tip = rng[0]
    ok_ids = reviewed(tip)
    blobs = binary_blobs(rng)
    if not blobs:
        raise ScanError("pre-push counted binary files, but none were found in the range")
    hide = withheld(sorted(set(blobs.values())), pattern)
    shown = lambda p: "(path withheld: it matches the list, or could not be checked)" if p in hide else p
    refused = 0
    for blob, path in sorted(blobs.items(), key=lambda kv: kv[1]):
        data = git("cat-file", "blob", blob)
        problems = [] if blob in ok_ids else [f"is not on the reviewed list ({LIST} at {tip[:12]})"]
        problems += structure(data) + string_problems(data, pattern, cfg)
        if problems:
            refused += 1
            print(f"  REFUSED  {blob[:12]}  {shown(path)}: " + "; ".join(problems), file=sys.stderr)
            if blob not in ok_ids:
                print(f"           once reviewed, add to {LIST}:  {blob}  {shown(path)}  YYYY-MM-DD  <who>  <what was checked>",
                      file=sys.stderr)
        else:
            print(f"  cleared  {blob[:12]}  {shown(path)}", file=sys.stderr)
    print(f"{len(blobs) - refused} of {len(blobs)} binary file(s) cleared", file=sys.stderr)
    return 1 if refused else 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: scan-binaries.py TIP [--not KNOWN...]", file=sys.stderr)
        sys.exit(2)
    try:
        sys.exit(main(sys.argv[1:]))
    except ScanError as e:
        print(f"scan-binaries: the scan did not run: {e}", file=sys.stderr)
        sys.exit(2)
    except (OSError, ValueError, struct.error) as e:
        print(f"scan-binaries: the scan did not run: {type(e).__name__}", file=sys.stderr)
        sys.exit(2)
