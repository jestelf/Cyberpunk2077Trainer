import argparse
import hashlib
import re
import struct
from pathlib import Path

def clean(path):
    original = path.read_bytes()
    data = bytearray(original)
    pe = struct.unpack_from('<I', data, 0x3c)[0]
    if data[pe:pe + 4] != b'PE\0\0':
        raise ValueError('Not a PE file')
    sections = struct.unpack_from('<H', data, pe + 6)[0]
    optional_size = struct.unpack_from('<H', data, pe + 20)[0]
    optional = pe + 24
    directory = optional + (112 if struct.unpack_from('<H', data, optional)[0] == 0x20b else 96)
    table = optional + optional_size
    section_info = []
    for i in range(sections):
        header = table + 40 * i
        virtual_size, rva, size, raw = struct.unpack_from('<IIII', data, header + 8)
        flags = struct.unpack_from('<I', data, header + 36)[0]
        section_info.append((rva, max(virtual_size, size), raw, size, flags))

    def offset(address):
        for rva, span, raw, size, flags in section_info:
            if rva <= address < rva + span:
                return raw + address - rva
        raise ValueError('Invalid RVA')

    debug_rva, debug_size = struct.unpack_from('<II', data, directory + 6 * 8)
    if debug_rva:
        debug = offset(debug_rva)
        for p in range(debug, debug + debug_size, 28):
            kind, size, address, raw = struct.unpack_from('<IIII', data, p + 12)
            if kind == 2 and raw and raw + size <= len(data):
                data[raw:raw + size] = bytes(size)
        struct.pack_into('<II', data, directory + 6 * 8, 0, 0)

    count = 0
    for pattern, encoding in [(rb'[A-Za-z]:[\\/][\x20-\x7e]+(?=\x00)', 'ascii'),
                               (rb'[A-Za-z]\x00:\x00[\\/]\x00(?:[\x20-\x7e]\x00)+(?=\x00\x00)', 'utf-16-le')]:
        for match in list(re.finditer(pattern, data)):
            value = match.group().decode(encoding)
            if '\\Users\\' not in value and '/Users/' not in value:
                continue
            name = re.split(r'[\\/]', value)[-1].encode(encoding)
            data[match.start():match.end()] = name + bytes(len(match.group()) - len(name))
            count += 1
    for rva, span, raw, size, flags in section_info:
        if flags & 0x20000000 and data[raw:raw + size] != original[raw:raw + size]:
            raise ValueError('Executable section changed')
    if len(data) != len(original):
        raise ValueError('File size changed')
    path.write_bytes(data)
    print(path.name, 'diagnostic paths:', count, 'SHA256:', hashlib.sha256(data).hexdigest())

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Remove CodeView metadata and personal diagnostic paths; preserve executable sections.')
    parser.add_argument('files', nargs='+', type=Path)
    for path in parser.parse_args().files:
        clean(path)
