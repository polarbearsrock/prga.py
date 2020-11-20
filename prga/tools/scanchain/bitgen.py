# -*- encoding: ascii -*-

from ..util import create_argparser, docstring_from_argparser
from ...core.context import Context
from ...core.common import ModuleView
from ...passes.vpr.arch import FASM_NONE
from ...util import enable_stdout_logging

import re   # for the simple FASM, regexp processing is good enough
import struct
from bitarray import bitarray
import logging

__all__ = ['bitgen_scanchain']

# Argument parser
import argparse
_parser = create_argparser(__name__, description="Bitstream generator for scanchain configuration circuitry")

_parser.add_argument('summary', type=argparse.FileType("rb"),
        help="Pickled architecture context or summary object")
_parser.add_argument('fasm', type=argparse.FileType('r'),
        help="FASM generated by the genfasm util of VPR")
_parser.add_argument('memh', type=argparse.FileType('w'),
        help="Generated bitstream in MEMH format for Verilog simulation")

# update docstring
__doc__ = docstring_from_argparser(_parser)

_logger = logging.getLogger(__name__)
_reprog_param = re.compile("^(?P<slices>\w+)\[(?P<high>\d+):(?P<low>\d+)\]=(?P<width>\d+)'b(?P<content>[01]+)$")
_reprog_slice = re.compile("^l(?P<low>\d+)r(?P<range>\d+)$")

def bitgen_scanchain(bitstream_size     # bitstream size
        , istream                       # input file-like object
        , ostream                       # output file-like object
        ):
    """Generate bitstream for scanchain configuration circuitry.

    Args:
        bitstream_size (:obj:`int`): bitstream size
        istream (file-like object):
        ostream (file-like object):
    """
    qwords = bitstream_size // 64
    remainder = bitstream_size % 64 
    if remainder > 0:
        qwords += 1
    bits = bitarray('0', endian='little') * (qwords * 64)
    # process features
    for lineno, line in enumerate(istream):
        segments = line.strip().split('.')
        if FASM_NONE in segments:
            continue
        base = sum(int(segment[1:]) for segment in segments[:-1])
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
                bits[base + sl : base + sl + rg] = segment[cur : cur + rg]
                cur += rg
            if cur != actual_width:
                raise RuntimeError("LINE {:>08d}: Sum of slices mismatches with number of bits"
                        .format(lineno + 1))
        else:
            bits[base + int(segments[-1][1:])] = True
    # emit lines in quad words
    for i in reversed(range(qwords)):
        ostream.write('{:0>16x}'.format(struct.unpack('<Q', bits[i*64:(i + 1)*64].tobytes())[0]) + '\n')

if __name__ == '__main__':
    args = _parser.parse_args()
    enable_stdout_logging(__name__, logging.INFO)
    summary = Context.unpickle(args.summary)
    if isinstance(summary, Context):
        summary = summary.summary
    bitstream_size = summary.scanchain["bitstream_size"]
    _logger.info("Architecture context summary parsed")
    _logger.info("Bitstream size: {}".format(bitstream_size))
    bitgen_scanchain(bitstream_size, args.fasm, args.memh)
    _logger.info("Bitstream generated. Bye")
