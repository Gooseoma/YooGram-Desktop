# Makes FFmpeg's ./configure recognize MSVC tools with a non-English Visual
# Studio. It looks for the English banner of cl.exe / lib.exe ("^Microsoft") and
# the word "Linker"; on a localized toolchain (e.g. Russian) neither is found,
# so the compiler is treated as an unknown one and invoked with "-o" instead of
# "-Fo", which ends with LNK1136 in the first compiler test.
#
# Run from the FFmpeg source directory.
import pathlib
import sys

REPLACEMENTS = [
    # cl.exe / lib.exe banner: not only at the start of the line.
    ('grep -q ^Microsoft', 'grep -q Microsoft'),
    ('grep ^Microsoft', 'grep Microsoft'),
    # Tell the linker wrapper (mslink) from the compiler by the tool name.
    ('if $_cc -nologo- 2>&1 | grep -q Linker; then',
     'if echo "$_cc" | grep -qi link; then'),
]

path = pathlib.Path('configure')
data = path.read_bytes()
for old, new in REPLACEMENTS:
    old_b = old.encode('utf-8')
    if old_b not in data:
        print('ffmpeg_msvc_locale: pattern not found: ' + old)
        continue
    data = data.replace(old_b, new.encode('utf-8'))
    print('ffmpeg_msvc_locale: patched: ' + old)
path.write_bytes(data)
sys.exit(0)
