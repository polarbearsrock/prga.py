# -*- encoding: ascii -*-

from ..common import AbstractProgCircuitryEntry
from ...core.common import NetClass, ModuleClass, ModuleView
from ...core.context import Context
from ...netlist import TimingArcType, PortDirection, Module, ModuleUtils, NetUtils, Const
from ...passes.base import AbstractPass
from ...passes.translation import SwitchDelegate
from ...passes.vpr.delegate import FASMDelegate
from ...util import Object, uno, Enum

__all__ = ['Magic']

# ----------------------------------------------------------------------------
# -- FASM Delegate -----------------------------------------------------------
# ----------------------------------------------------------------------------
class MagicFASMDelegate(FASMDelegate):
    """FASM Delegate for magic programming circuitry (not ASIC implementable).
    
    Args:
        context (`Context`):
    """

    _none = object()

    __slots__ = ["context"]
    def __init__(self, context):
        self.context = context

    @classmethod
    def __hierarchy_prefix(cls, hierarchy = None):
        if hierarchy is None:
            return ""
        else:
            return ".".join(i.name for i in reversed(hierarchy.hierarchy)) + "."

    @classmethod
    def __enable(cls, enable):
        if enable.mask is None:
            if enable.range_.base == 0:
                return "~{}'h{:x}".format(enable.range_.length, enable.value)
            else:
                return "+{}.~{}'h{:x}".format(enable.range_.base, enable.range_.length, enable.value)
        else:
            if enable.range_.base == 0:
                return "&{}.~{}'h{:x}".format(enable.mask, enable.range_.length, enable.value)
            else:
                return "+{}.&{}.~{}'h{:x}".format(enable.range_.base, enable.mask, enable.range_.length, enable.value)

    def fasm_mux_for_intrablock_switch(self, source, sink, hierarchy = None):
        conn = NetUtils.get_connection(source, sink, skip_validations = True)
        if (prog_enable := getattr(conn, "prog_enable", self._none)) is not self._none:
            if prog_enable is None:
                return tuple()
            else:
                return self.__enable(prog_enable), # the trailing comma converts it to a single-element tuple
        fasm_features = []
        for net in getattr(conn, "logical_path", tuple()):
            bus, idx = (net.bus, net.index) if net.net_type.is_bit else (net, 0)
            fasm_features.append("{}.{}"
                .format(bus.instance.name, self.__enable(bus.instance.model.prog_enable[idx])))
        return tuple(fasm_features)

    def fasm_params_for_primitive(self, instance):
        leaf = instance.hierarchy[0]
        if (parameters := getattr(leaf, "prog_parameters", self._none)) is self._none:
            if (parameters := getattr(leaf.model, "prog_parameters", self._none)) is self._none:
                return {}
        return {k: "[{}:{}]".format(v.base + v.length - 1, v.base)
                for k, v in uno(parameters, {}).items()}

    def fasm_prefix_for_intrablock_module(self, module, hierarchy = None):
        if hierarchy:
            leaf = hierarchy.hierarchy[0]
            if (prog_offset := getattr(leaf, "prog_offset", self._none)) is not self._none:
                return "+{}".format(prog_offset)
            else:
                return leaf.name
        else:
            return None

    def fasm_features_for_intrablock_module(self, module, hierarchy = None):
        if (module.module_class.is_mode
                or hierarchy is None
                or (prog_enable := getattr(hierarchy.hierarchy[0], "prog_enable", self._none)) is self._none):
            prog_enable = getattr(module, "prog_enable", None)
        if prog_enable is None:
            return tuple()
        else:
            return self.__enable(prog_enable),

    def fasm_lut(self, instance):
        leaf = instance.hierarchy[0]
        if (parameters := getattr(leaf, "prog_parameters", self._none)) is self._none:
            if (parameters := getattr(leaf.model, "prog_parameters", self._none)) is self._none:
                return None
        if (range_ := parameters.get("lut")) is not None:
            return '[{}:{}]'.format(range_.base + range_.length - 1, range_.base)
        else:
            return None

    def fasm_prefix_for_tile(self, instance):
        prefix = self.__hierarchy_prefix(instance)
        retval = []
        for subtile, blkinst in instance.model.instances.items():
            if not isinstance(subtile, int):
                continue
            elif subtile >= len(retval):
                retval.extend(None for _ in range(subtile - len(retval) + 1))
            retval[subtile] = prefix + blkinst.name
        return tuple(retval)

    def fasm_features_for_interblock_switch(self, source, sink, hierarchy = None):
        prefix = self.__hierarchy_prefix(hierarchy)
        return tuple(prefix + feature for feature in self.fasm_mux_for_intrablock_switch(source, sink, hierarchy))

# ----------------------------------------------------------------------------
# -- Magic Configuration Circuitry Main Entry --------------------------------
# ----------------------------------------------------------------------------
class Magic(AbstractProgCircuitryEntry):
    """Entry point for magic programming circuitry (not ASIC implementable)."""

    @classmethod
    def new_context(cls):
        ctx = Context("magic")
        ctx._switch_delegate = SwitchDelegate(ctx)
        ctx._fasm_delegate = MagicFASMDelegate(ctx)
        return ctx

    class InsertProgCircuitry(AbstractPass):
        """Insert [fake] programming circuitry."""

        @classmethod
        def __process_module(cls, context, logical_module = None, _cache = None):
            """Set ``prog_data`` of leaf modules to default 0."""
            # short alias
            lmod = uno(logical_module, context.database[ModuleView.logical, context.top.key])

            # check if we should process ``logical_module``
            if lmod.module_class in (ModuleClass.primitive, ModuleClass.switch, ModuleClass.prog, ModuleClass.aux):
                return

            # check if we've processed ``logical_module``
            _cache = uno(_cache, set())
            if lmod.key in _cache:
                return
            _cache.add(lmod.key)

            # process ``lmod``
            if (lmod.module_class.is_tile or lmod.module_class.is_array or
                    lmod.module_class.is_slice or lmod.module_class.is_block):
                for i in lmod.instances.values():
                    cls.__process_module(context, i.model, _cache)

            if lmod.module_class.is_slice or lmod.module_class.is_block or lmod.module_class.is_routing_box:
                # connect ``prog_data`` to constant 0
                for i in lmod.instances.values():
                    if (pin := i.pins.get("prog_data")) is not None:
                        NetUtils.connect(Const(0, len(pin)), pin)

        def run(self, context, renderer = None):
            self.__process_module(context)
            AbstractProgCircuitryEntry.buffer_prog_ctrl(context)

        @property
        def key(self):
            return "prog.insertion.magic"

        @property
        def dependences(self):
            return ("annotation.logical_path", )

        @property
        def passes_after_self(self):
            return ("rtl", )
