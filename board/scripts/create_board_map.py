#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

import argparse
import re

class BoardMap:

    def __init__(self):
        self._address_map = {}
        return

    def Analyze(self, filename):
        with open(filename) as f:
            for line in f.readlines():
                line = line.strip().replace('[','').replace(']','')
                tokens = line.split(' ')
                if tokens[0] != 'assign_bd_address':
                    continue
                idx = 1
                source_name = None
                dest_name = None
                address = None
                size = None
                while idx < len(tokens):
                    if tokens[idx] == '-offset':
                        idx += 1
                        address = tokens[idx]
                    elif tokens[idx] == '-range':
                        idx += 1
                        size = tokens[idx]
                    elif tokens[idx] == '-target_address_space':
                        source_cmd = tokens[idx+1]
                        source_name = tokens[idx+2]
                        dest_cmd = tokens[idx+3]
                        dest_name = tokens[idx+4]
                        idx += 4
                    idx += 1
                if address is None or size is None or dest_name is None or source_name is None:
                    continue
                if 'M_AXI_LITE' in source_name and 'xdma' in source_name:
                    self._address_map[dest_name] = (address, size)
                elif 'ddr' in dest_name and 'MEMORY_MAP' in dest_name:
                    mem_name = re.sub('/.*', '', dest_name)
                    self._address_map[mem_name] = (address, size)

    def PrintMap(self):
        for name in self._address_map:
            print(name, self._address_map[name])

    def CreateBRAMSource(self, filename):
        max_len = 0
        names = []
        addresses = []
        sizes = []
        for name in self._address_map:
            name_bytes = name.encode()
            name_strs = []
            name_str = ''
            for i in range(0,len(name_bytes)):
                name_hex = '{:02x}'.format(name_bytes[i])
                name_str = str(name_hex) + name_str
                if (i % 4) == 3:
                    name_strs.append(name_str)
                    name_str = ''
            remain = len(name_bytes) % 4
            if remain > 0:
                name_str = '00'*(4-remain) + name_str
                name_strs.append(name_str)
            names.append(name_strs)
            if max_len < ((len(name_bytes) + 3) & ~3):
                max_len = (len(name_bytes) + 3) & ~3
            (org_address, org_size) = self._address_map[name]
            address = int(org_address, 0)
            size = int(org_size, 0)
            address_shift = 0
            if address > 0:
                while (address % 2) == 0:
                    address_shift += 1
                    address >>= 1
            size_shift = 0
            while (size % 2) == 0:
                size_shift += 1
                size >>= 1
            if address >= 2**24 or size >= 2**24:
                raise ValueError(f'address={address},size={size}')
            address_str = f'{address_shift:02x}{address:06x}'
            size_str = f'{size_shift:02x}{size:06x}'
            addresses.append(address_str)
            sizes.append(size_str)

        cur_len = 4
        while cur_len < max_len + 12:
            cur_len *= 2
        cur_len_hex = '{:08x}'.format(cur_len)

        name_list = list(self._address_map.keys())

        with open(filename, mode='w') as f:
            f.write('memory_initialization_radix=16;\n')
            f.write('memory_initialization_vector=\n')
            for idx in range(0, len(addresses)):
                data = [cur_len_hex, addresses[idx], sizes[idx]]
                data.extend(names[idx])
                while len(data) < cur_len/4:
                    data.append('00000000')
                addr = idx * cur_len
                #f.write('    ; ' + name_list[idx] + '\n')
                line_data = ''
                for pos in range(0, len(data)):
                    if (pos & 3) == 0:
                        addr_hex = '{:04x}'.format(addr+pos*4)
                        #line_data += ' '*4 + addr_hex + ' :'
                    line_data += ' ' + data[pos]
                    if idx < len(addresses)-1 or pos < len(data)-1:
                        line_data += ','
                    else:
                        line_data += ';'
                    if (pos & 3) == 3:
                        f.write(line_data + '\n')
                        line_data = ''

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--input', required=True)
    parser.add_argument('-o', '--output', required=True)
    parser.add_argument('-v', '--verbose', action='store_true')

    args = parser.parse_args()

    board_map = BoardMap()
    board_map.Analyze(args.input)
    if args.verbose:
        board_map.PrintMap()
    board_map.CreateBRAMSource(args.output)
