# -*- encoding: ascii -*-

from ..util import create_argparser, docstring_from_argparser
from ...core.context import Context
from ...core.common import ModuleView
from ...passes.vpr.arch import FASM_NONE
from ...util import enable_stdout_logging
from ...exception import PRGAInternalError
from ...cfg.pktchain.protocol import PktchainProtocol

import re
import struct
from bitarray import bitarray
import logging
from itertools import product, count

__all__ = ['PktchainBitgen']

_logger = logging.getLogger(__name__)
_reprog_param = re.compile("^(?P<slices>\w+)\[(?P<high>\d+):(?P<low>\d+)\]=(?P<width>\d+)'b(?P<content>[01]+)$")
_reprog_slice = re.compile("^l(?P<low>\d+)r(?P<range>\d+)$")

import argparse
_parser = create_argparser(__name__,
        description="Bitstream generator for pktchain configuration circuitry")

_parser.add_argument('summary', type=argparse.FileType("rb"),
        help="Pickled architecture context or summary object")
_parser.add_argument('fasm', type=argparse.FileType('r'),
        help="FASM generated by the genfasm util of VPR")
_parser.add_argument('memh', type=argparse.FileType('wb'),
        help="Generated bitstream in MEMH format for Verilog simulation")

__doc__ = docstring_from_argparser(_parser)

class PktchainBitgen(object):
    _reversed_crc_lookup = {}   # to be filled later

    @classmethod
    def _int2bitseq(cls, v, bigendian = True):
        if bigendian:
            for i in reversed(range(v.bit_length())):
                yield 1 if v & (1 << i) else 0
        else:
            for i in range(v.bit_length()):
                yield 1 if v & (1 << i) else 0

    @classmethod
    def crc(cls, seq):
        crc = 0
        for i in seq:
            crc = ((crc << 1) & 0xFF) ^ (0x7 if bool(crc & 0x80) != bool(i) else 0x0)
        return crc

    @classmethod
    def reverse_crc(cls, crc, zeros = 0):
        for i in range(zeros):
            crc = (crc >> 1) ^ (0x83 if crc & 1 else 0x0)
        # check pre-built CRC lookup table
        try:
            return cls._reversed_crc_lookup[crc]
        except KeyError:
            raise PRGAInternalError("No prefix checksum found for CRC-8 CCITT value 0x{:08x} prepended with {} zeros"
                    .format(crc, zeros))

    @classmethod
    def bitgen(cls,
            summary                     # context summary object
            , istream                   # input file-like object
            , ostream                   # output file-like object
            ):
        """Generate bitstream for pktchain configuration circuitry.

        Args:
            summary (:obj:`Mappping`): Pktchain summary object
            istream (file-like object):
            ostream (file-like object):
        """
        fabric = summary.pktchain["fabric"]
        bits = [[bitarray('0', endian='little') * bitcount
            for y, bitcount in enumerate(col)] for x, col in enumerate(fabric["chains"])]
        # process features
        for lineno, line in enumerate(istream):
            segments = line.strip().split(".")
            if FASM_NONE in segments:
                continue
            x, y, base = 0, 0, 0
            for sgmt in segments[:-1]:
                if sgmt[0] == 'x':
                    x += int(sgmt[1:])
                elif sgmt[0] == 'y':
                    y += int(sgmt[1:])
                elif sgmt[0] == 'b':
                    base += int(sgmt[1:])
                else:
                    raise PRGAInternalError("LINE {:>08d}: Invalid FASM feature line {}".format(lineno + 1, line.strip()))
            if '[' in segments[-1]:
                matched = _reprog_param.match(segments[-1])
                high, low, width = map(lambda x: int(matched.group(x)), ('high', 'low', 'width'))
                base += low
                segment = bitarray(matched.group('content'))
                segment.reverse()
                if high < low:
                    raise RuntimeError("LINE {:>08d}: Invalid range specifier".format(lineno + 1))
                elif width != len(segment):
                    raise RuntimeError("LINE {:>08d}: Explicit width specifier mismatches with number of bits"
                            .format(lineno + 1))
                actual_width = high - low + 1
                if actual_width > width:
                    segment.extend((False, ) * (actual_width - width))
                cur = 0
                for slice_ in matched.group("slices").split('_'):
                    sl, rg = map(int, _reprog_slice.match(slice_).group("low", "range"))
                    bits[x][y][base + sl : base + sl + rg] = segment[cur : cur + rg]
                    cur += rg
                if cur != actual_width:
                    raise RuntimeError("LINE {:>08d}: Sum of slices mismatches with number of bits"
                            .format(lineno + 1))
            else:
                bits[x][y][base + int(segments[-1][1:])] = True
        # complete each tile
        cfg_width = summary.scanchain["cfg_width"]
        for x, col in enumerate(bits):
            for y, tile in enumerate(col):
                crc = [cls.crc(iter(b for i, b in enumerate(reversed(tile)) if i % (cfg_width) == idx))
                        for idx in reversed(range(cfg_width))]
                reversed_crc = [cls.reverse_crc(c, len(tile) // cfg_width) for c in crc]
                checksum = bitarray(endian="little")
                # fill checksum
                for digit, idx in product(range(8), range(cfg_width)):
                    checksum.append(bool(reversed_crc[idx] & (1 << digit)))
                # prepend & append checksum
                fullstream = checksum + tile + checksum
                # align to 32bit (frame size) boundaries
                if len(fullstream) % 32 != 0:
                    remainder = 32 - len(fullstream) % 32
                    fullstream += bitarray("0", endian="little") * remainder
                col[y] = fullstream
        # dump the bitstream (or more precisely, the "packet" stream)
        max_packet_frames = min(256, (2 ** fabric["router_fifo_depth_log2"]) // (32 // fabric["phit_width"])) - 1
        for pkt in count():
            completed = True
            for y, x in product(reversed(range(len(bits[0]))), reversed(range(len(bits)))):
                bitstream = bits[x][y]
                if not any(bitstream):
                    continue
                total_frames = len(bitstream) // 32
                if pkt * max_packet_frames >= total_frames:
                    continue
                init = pkt == 0
                checksum = (pkt + 1) * max_packet_frames >= total_frames
                completed = completed and checksum
                msg_type = (PktchainProtocol.Programming.MSGType.DATA_INIT_CHECKSUM if init and checksum else
                        PktchainProtocol.Programming.MSGType.DATA_INIT if init and not checksum else
                        PktchainProtocol.Programming.MSGType.DATA_CHECKSUM if not init and checksum else
                        PktchainProtocol.Programming.MSGType.DATA)
                payload = min(max_packet_frames, total_frames - pkt * max_packet_frames)
                ostream.write("// {} packet to ({}, {}), {} frames\n"
                        .format(msg_type.name, x, y, payload).encode("ascii"))
                ostream.write("{:0>8x}\n"
                        .format(PktchainProtocol.Programming.encode_msg_header(msg_type, x, y, payload))
                        .encode("ascii"))
                for i in range(payload):
                    i = total_frames - pkt * max_packet_frames - 1 - i
                    ostream.write("{:0>8x}\n".format(
                        struct.unpack("<L", bitstream[i*32:(i + 1)*32].tobytes())[0]).encode("ascii"))
                ostream.write("\n".encode("ascii"))
            if completed:
                break

PktchainBitgen._reversed_crc_lookup = {
        PktchainBitgen.crc(PktchainBitgen._int2bitseq(i)) : i
        for i in range(256)}

if __name__ == '__main__':
    args = _parser.parse_args()
    enable_stdout_logging(__name__, logging.INFO)
    summary = Context.unpickle(args.summary)
    if isinstance(summary, Context):
        summary = summary.summary
    _logger.info("Architecture context summary parsed")
    PktchainBitgen.bitgen(summary, args.fasm, args.memh)
    _logger.info("Bitstream generated. Bye")
