# -*- encoding: ascii -*-

from ..core.common import ModuleView, ModuleClass, PrimitiveClass, PrimitivePortClass, NetClass, IOType
from ..prog import ProgDataRange, ProgDataValue
from ..netlist import Module, NetUtils, ModuleUtils, PortDirection, TimingArcType

from itertools import product

# ----------------------------------------------------------------------------
# -- Builtin Cell Libraries --------------------------------------------------
# ----------------------------------------------------------------------------
class BuiltinCellLibrary(object):
    """A host class for built-in cells."""

    @classmethod
    def _register_luts(cls, context, dont_add_logical_primitives):
        for i in range(2, 9):
            name = "lut" + str(i)

            # user
            umod = context._database[ModuleView.user, name] = Module(name,
                    is_cell = True,
                    view = ModuleView.user,
                    module_class = ModuleClass.primitive,
                    primitive_class = PrimitiveClass.lut)
            in_ = ModuleUtils.create_port(umod, 'in', i, PortDirection.input_,
                    port_class = PrimitivePortClass.lut_in)
            out = ModuleUtils.create_port(umod, 'out', 1, PortDirection.output,
                    port_class = PrimitivePortClass.lut_out)
            NetUtils.create_timing_arc(TimingArcType.comb_matrix, in_, out)

            # logical
            if name not in dont_add_logical_primitives:
                lmod = context._database[ModuleView.logical, name] = Module(name,
                        is_cell = True,
                        view = ModuleView.logical,
                        module_class = ModuleClass.primitive, 
                        primitive_class = PrimitiveClass.lut,
                        verilog_template = "builtin/lut.tmpl.v")
                in_ = ModuleUtils.create_port(lmod, 'in', i, PortDirection.input_,
                        net_class = NetClass.user, port_class = PrimitivePortClass.lut_in)
                out = ModuleUtils.create_port(lmod, 'out', 1, PortDirection.output,
                        net_class = NetClass.user, port_class = PrimitivePortClass.lut_out)
                NetUtils.create_timing_arc(TimingArcType.comb_matrix, in_, out)
                ModuleUtils.create_port(lmod, "prog_done", 1,          PortDirection.input_, net_class = NetClass.prog)
                ModuleUtils.create_port(lmod, "prog_data", 2 ** i + 1, PortDirection.input_, net_class = NetClass.prog)

                # mark programming data bitmap
                umod.prog_enable = ProgDataValue(ProgDataRange(2 ** i, 1), 1)
                umod.prog_parameters = { "lut": ProgDataRange(0, 2 ** i) }

    @classmethod
    def _register_flipflop(cls, context, dont_add_logical_primitives):
        name = "flipflop"

        # user
        umod = context._database[ModuleView.user, name] = Module(name,
                is_cell = True,
                view = ModuleView.user,
                module_class = ModuleClass.primitive,
                primitive_class = PrimitiveClass.flipflop)
        clk = ModuleUtils.create_port(umod, "clk", 1, PortDirection.input_, is_clock = True,
                port_class = PrimitivePortClass.clock)
        D = ModuleUtils.create_port(umod, "D", 1, PortDirection.input_,
                port_class = PrimitivePortClass.D)
        Q = ModuleUtils.create_port(umod, "Q", 1, PortDirection.output,
                port_class = PrimitivePortClass.Q)
        NetUtils.create_timing_arc(TimingArcType.seq_end, clk, D)
        NetUtils.create_timing_arc(TimingArcType.seq_start, clk, Q)

        # logical
        if name not in dont_add_logical_primitives:
            lmod = context._database[ModuleView.logical, name] = Module(name,
                    is_cell = True,
                    view = ModuleView.logical,
                    module_class = ModuleClass.primitive,
                    primitive_class = PrimitiveClass.flipflop,
                    verilog_template = "builtin/flipflop.tmpl.v")
            clk = ModuleUtils.create_port(lmod, "clk", 1, PortDirection.input_, is_clock = True,
                    net_class = NetClass.user, port_class = PrimitivePortClass.clock)
            D = ModuleUtils.create_port(lmod, "D", 1, PortDirection.input_,
                    net_class = NetClass.user, port_class = PrimitivePortClass.D)
            Q = ModuleUtils.create_port(lmod, "Q", 1, PortDirection.output,
                    net_class = NetClass.user, port_class = PrimitivePortClass.Q)
            NetUtils.create_timing_arc(TimingArcType.seq_end, clk, D)
            NetUtils.create_timing_arc(TimingArcType.seq_start, clk, Q)
            ModuleUtils.create_port(lmod, "prog_done", 1, PortDirection.input_, net_class = NetClass.prog)
            ModuleUtils.create_port(lmod, "prog_data", 1, PortDirection.input_, net_class = NetClass.prog)

            # mark programming data bitmap
            umod.prog_enable = ProgDataValue(ProgDataRange(0, 1), 1)

    @classmethod
    def _register_io(cls, context, dont_add_logical_primitives):
        # register single-mode I/O
        for name in ("inpad", "outpad"):
            # user
            umod = context._database[ModuleView.user, name] = Module(name,
                    is_cell = True,
                    view = ModuleView.user,
                    module_class = ModuleClass.primitive,
                    primitive_class = PrimitiveClass[name])
            if name == "inpad":
                ModuleUtils.create_port(umod, "inpad", 1, PortDirection.output)
            else:
                ModuleUtils.create_port(umod, "outpad", 1, PortDirection.input_)

            # logical
            if name not in dont_add_logical_primitives:
                lmod = context._database[ModuleView.logical, name] = Module(name,
                        is_cell = True,
                        view = ModuleView.logical,
                        module_class = ModuleClass.primitive,
                        primitive_class = PrimitiveClass[name],
                        verilog_template = "builtin/{}.tmpl.v".format(name))
                if name == "inpad":
                    u = ModuleUtils.create_port(lmod, "inpad", 1, PortDirection.output, net_class = NetClass.user)
                    l = ModuleUtils.create_port(lmod, "ipin", 1, PortDirection.input_,
                            net_class = NetClass.io, key = IOType.ipin)
                    NetUtils.create_timing_arc(TimingArcType.comb_bitwise, l, u)
                else:
                    u = ModuleUtils.create_port(lmod, "outpad", 1, PortDirection.input_, net_class = NetClass.user)
                    l = ModuleUtils.create_port(lmod, "opin", 1, PortDirection.output,
                            net_class = NetClass.io, key = IOType.opin)
                    NetUtils.create_timing_arc(TimingArcType.comb_bitwise, u, l)
                ModuleUtils.create_port(lmod, "prog_done", 1, PortDirection.input_, net_class = NetClass.prog)
                ModuleUtils.create_port(lmod, "prog_data", 1, PortDirection.input_, net_class = NetClass.prog)

                # mark programming data bitmap
                umod.prog_enable = ProgDataValue(ProgDataRange(0, 1), 1)

        # register dual-mode I/O
        if True:
            # user
            ubdr = context.build_multimode("iopad")
            ubdr.create_input("outpad", 1)
            ubdr.create_output("inpad", 1)

            # user modes
            mode_input = ubdr.build_mode("mode_input")
            inst = mode_input.instantiate(
                    context.database[ModuleView.user, "inpad"],
                    "i_pad")
            mode_input.connect(inst.pins["inpad"], mode_input.ports["inpad"])
            mode_input.commit()

            mode_output = ubdr.build_mode("mode_output")
            inst = mode_output.instantiate(
                    context.database[ModuleView.user, "outpad"],
                    "o_pad")
            mode_output.connect(mode_output.ports["outpad"], inst.pins["outpad"])
            mode_output.commit()

            # logical
            if name not in dont_add_logical_primitives:
                lbdr = ubdr.build_logical_counterpart(verilog_template = "builtin/iopad.tmpl.v")
                ipin = ModuleUtils.create_port(lbdr.module, "ipin", 1, PortDirection.input_,
                        net_class = NetClass.io, key = IOType.ipin)
                opin = ModuleUtils.create_port(lbdr.module, "opin", 1, PortDirection.output,
                        net_class = NetClass.io, key = IOType.opin)
                oe = ModuleUtils.create_port(lbdr.module, "oe", 1, PortDirection.output,
                        net_class = NetClass.io, key = IOType.oe)
                NetUtils.create_timing_arc(TimingArcType.comb_bitwise, ipin, lbdr.ports["inpad"])
                NetUtils.create_timing_arc(TimingArcType.comb_bitwise, lbdr.ports["outpad"], opin)
                lbdr.create_prog_port("prog_done", 1, PortDirection.input_)
                lbdr.create_prog_port("prog_data", 2, PortDirection.input_)

                lbdr.commit()

                # mark programming data bitmap
                i = ubdr.module.modes["mode_input"].instances["i_pad"]
                i.prog_enable = ProgDataValue(ProgDataRange(0, 2), 1)
                i.prog_offset = 0

                o = ubdr.module.modes["mode_output"].instances["o_pad"]
                o.prog_enable = ProgDataValue(ProgDataRange(0, 2), 2)
                o.prog_offset = 0

            else:
                ubdr.commit()

    @classmethod
    def _register_u_adder(cls, context, dont_add_logical_primitives):
        ubdr = context.build_primitive("adder",
                techmap_template = "adder/techmap.tmpl.v",
                verilog_template = "adder/lib.tmpl.v",
                vpr_model = "m_adder",
                prog_parameters = { "CIN_MODE": ProgDataRange(0, 2), },
                )
        inputs = [
                ubdr.create_input("a", 1),
                ubdr.create_input("b", 1),
                ubdr.create_input("cin", 1),
                ubdr.create_input("cin_fabric", 1),
                ]
        outputs = [
                ubdr.create_output("cout", 1),
                ubdr.create_output("s", 1),
                ubdr.create_output("cout_fabric", 1),
                ]
        for i, o in product(inputs, outputs):
            ubdr.create_timing_arc(TimingArcType.comb_bitwise, i, o)

        ubdr.commit()

    @classmethod
    def _register_fle6(cls, context, dont_add_logical_primitives):
        ubdr = context.build_multimode("fle6")
        ubdr.create_clock("clk")
        ubdr.create_input("in", 6)
        ubdr.create_input("cin", 1)
        ubdr.create_output("out", 2)
        ubdr.create_output("cout", 1)

        # user modes
        # mode (1): arith
        if True:
            mode = ubdr.build_mode("arith")
            adder = mode.instantiate(context.primitives["adder"], "i_adder")
            luts = mode.instantiate(context.primitives["lut5"], "i_lut5", 2)
            ffs = mode.instantiate(context.primitives["flipflop"], "i_flipflop", 2)
            mode.connect(mode.ports["cin"], adder.pins["cin"], vpr_pack_patterns = ["carrychain"])
            mode.connect(mode.ports["in"][5], adder.pins["cin_fabric"])
            for i, (p, lut) in enumerate(zip(["a", "b"], luts)):
                mode.connect(mode.ports["in"][4:0], lut.pins["in"])
                mode.connect(lut.pins["out"], adder.pins[p], vpr_pack_patterns = ["carrychain"])
            for i, (p, ff) in enumerate(zip(["s", "cout_fabric"], ffs)):
                mode.connect(mode.ports["clk"], ff.pins["clk"])
                mode.connect(adder.pins[p], ff.pins["D"], vpr_pack_patterns = ["carrychain"])
                mode.connect(adder.pins[p], mode.ports["out"][i])
                mode.connect(ff.pins["Q"], mode.ports["out"][i])
            mode.connect(adder.pins["cout"], mode.ports["cout"], vpr_pack_patterns = ["carrychain"])
            mode.commit()

        # mode (2): LUT6x1
        if True:
            mode = ubdr.build_mode("lut6x1")
            lut = mode.instantiate(context.primitives["lut6"], "i_lut6")
            ff = mode.instantiate(context.primitives["flipflop"], "i_flipflop")
            mode.connect(mode.ports["clk"], ff.pins["clk"])
            mode.connect(mode.ports["in"], lut.pins["in"])
            mode.connect(lut.pins["out"], ff.pins["D"], vpr_pack_patterns = ["lut6_dff"])
            mode.connect(lut.pins["out"], mode.ports["out"][0])
            mode.connect(ff.pins["Q"], mode.ports["out"][0])
            mode.commit()

        # mode (3): LUT5x2
        if True:
            mode = ubdr.build_mode("lut5x2")
            for i, (lut, ff) in enumerate(zip(
                mode.instantiate(context.primitives["lut5"], "i_lut5", 2),
                mode.instantiate(context.primitives["flipflop"], "i_flipflop", 2)
                )):
                mode.connect(mode.ports["clk"], ff.pins["clk"])
                mode.connect(mode.ports["in"][4:0], lut.pins["in"])
                mode.connect(lut.pins["out"], ff.pins["D"], vpr_pack_patterns = ["lut5_i{}_dff".format(i)])
                mode.connect(lut.pins["out"], mode.ports["out"][i])
                mode.connect(ff.pins["Q"], mode.ports["out"][i])
            mode.commit()

        # logical view
        if "fle6" not in dont_add_logical_primitives:
            lbdr = ubdr.build_logical_counterpart(verilog_template = "fle6/fle6.tmpl.v")
            NetUtils.create_timing_arc(TimingArcType.comb_matrix, lbdr.ports["in"], lbdr.ports["out"])
            NetUtils.create_timing_arc(TimingArcType.comb_matrix, lbdr.ports["cin"], lbdr.ports["out"])
            NetUtils.create_timing_arc(TimingArcType.comb_matrix, lbdr.ports["in"], lbdr.ports["cout"])
            NetUtils.create_timing_arc(TimingArcType.comb_matrix, lbdr.ports["cin"], lbdr.ports["cout"])
            NetUtils.create_timing_arc(TimingArcType.seq_start, lbdr.ports["clk"], lbdr.ports["out"])
            NetUtils.create_timing_arc(TimingArcType.seq_end, lbdr.ports["clk"], lbdr.ports["in"])
            NetUtils.create_timing_arc(TimingArcType.seq_end, lbdr.ports["clk"], lbdr.ports["cin"])
            lbdr.create_prog_port("prog_done", 1, PortDirection.input_)
            lbdr.create_prog_port("prog_data", 70, PortDirection.input_)

            lbdr.commit()

            # mark programming data bitmap
            # mode (1): arith
            mode = ubdr.module.modes["arith"]
            mode.prog_enable = ProgDataValue(ProgDataRange(68, 2), 1)

            adder = mode.instances["i_adder"]
            adder.prog_offset = 0
            adder.prog_parameters = { "CIN_MODE": ProgDataRange(64, 2), }

            for i, p in enumerate(["s", "cout_fabric"]):
                conn = NetUtils.get_connection(mode.instances["i_flipflop", i].pins["Q"],
                        mode.ports["out"][i], skip_validations = True)
                conn.prog_enable = ProgDataValue(ProgDataRange(66 + i, 1), 0)

                conn = NetUtils.get_connection(adder.pins[p], mode.ports["out"][i], skip_validations = True)
                conn.prog_enable = ProgDataValue(ProgDataRange(66 + i, 1), 1)

            for i in range(2):
                lut = mode.instances["i_lut5", i]
                lut.prog_offset = 32 * i
                lut.prog_enable = None

                ff = mode.instances["i_flipflop", i]
                ff.prog_offset = 0
                ff.prog_enable = None

            # mode (2): lut6x1
            mode = ubdr.module.modes["lut6x1"]
            mode.prog_enable = ProgDataValue(ProgDataRange(68, 2), 2)

            lut = mode.instances["i_lut6"]
            lut.prog_offset = 0
            lut.prog_enable = None

            ff = mode.instances["i_flipflop"]
            ff.prog_offset = 0
            ff.prog_enable = None

            conn = NetUtils.get_connection(ff.pins["Q"], mode.ports["out"][0], skip_validations = True)
            conn.prog_enable = ProgDataValue(ProgDataRange(66, 1), 0)

            conn = NetUtils.get_connection(lut.pins["out"], mode.ports["out"][0], skip_validations = True)
            conn.prog_enable = ProgDataValue(ProgDataRange(66, 1), 1)

            # mode (3): lut5x2
            mode = ubdr.module.modes["lut5x2"]
            mode.prog_enable = ProgDataValue(ProgDataRange(68, 2), 3)

            for i in range(2):
                lut = mode.instances["i_lut5", i]
                lut.prog_offset = 32 * i
                lut.prog_enable = None

                ff = mode.instances["i_flipflop", i]
                ff.prog_offset = 0
                ff.prog_enable = None

                conn = NetUtils.get_connection(ff.pins["Q"], mode.ports["out"][i], skip_validations = True)
                conn.prog_enable = ProgDataValue(ProgDataRange(66 + i, 1), 0)

                conn = NetUtils.get_connection(lut.pins["out"], mode.ports["out"][i], skip_validations = True)
                conn.prog_enable = ProgDataValue(ProgDataRange(66 + i, 1), 1)
        else:
            ubdr.commit()

    @classmethod
    def _register_grady18(cls, context, dont_add_logical_primitives):
        # register a non-instantiate-able, non-translate-able multi-mode primitive: "grady18.ble5"
        ubdr = context.build_multimode("grady18.ble5")
        ubdr.create_clock("clk")
        ubdr.create_input("in", 5)
        ubdr.create_input("cin", 1)
        ubdr.create_output("out", 1)
        ubdr.create_output("cout", 1)
        ubdr.create_output("cout_fabric", 1)

        # user modes
        # mode (1): arith
        if True:
            mode = ubdr.build_mode("arith")
            adder = mode.instantiate(context.primitives["adder"], "i_adder")
            luts = mode.instantiate(context.primitives["lut4"], "i_lut4", 2)
            ff = mode.instantiate(context.primitives["flipflop"], "i_flipflop")
            mode.connect(mode.ports["clk"], ff.pins["clk"])
            mode.connect(mode.ports["cin"], adder.pins["cin"], vpr_pack_patterns = ["carrychain"])
            mode.connect(mode.ports["in"][4], adder.pins["cin_fabric"])
            for i, (p, lut) in enumerate(zip(["a", "b"], luts)):
                mode.connect(mode.ports["in"][3:0], lut.pins["in"])
                mode.connect(lut.pins["out"], adder.pins[p], vpr_pack_patterns = ["carrychain"])
            mode.connect(adder.pins["s"], ff.pins["D"], vpr_pack_patterns = ["carrychain"])
            mode.connect(adder.pins["s"], mode.ports["out"])
            mode.connect(ff.pins["Q"], mode.ports["out"])
            mode.connect(adder.pins["cout"], mode.ports["cout"], vpr_pack_patterns = ["carrychain"])
            mode.connect(adder.pins["cout_fabric"], mode.ports["cout_fabric"])
            mode.commit()

        # mode (2): lut5
        if True:
            mode = ubdr.build_mode("lut5")
            lut = mode.instantiate(context.primitives["lut5"], "i_lut5")
            ff = mode.instantiate(context.primitives["flipflop"], "i_flipflop")
            mode.connect(mode.ports["clk"], ff.pins["clk"])
            mode.connect(mode.ports["in"], lut.pins["in"])
            mode.connect(lut.pins["out"], ff.pins["D"], vpr_pack_patterns = ["lut5_dff"])
            mode.connect(lut.pins["out"], mode.ports["out"])
            mode.connect(ff.pins["Q"], mode.ports["out"])
            mode.commit()

        ble5 = ubdr.commit()

        # build FLE8
        ubdr = context.build_multimode("grady18")
        ubdr.create_clock("clk")
        ubdr.create_input("in", 8)
        ubdr.create_input("cin", 1)
        ubdr.create_output("out", 2)
        ubdr.create_output("cout", 1)
        ubdr.create_output("cout_fabric", 1)

        # user modes
        # mode (1): ble5x2
        if True:
            mode = ubdr.build_mode("ble5x2")
            ble5s = mode.instantiate(ble5, "i_ble5", 2)
            for i, inst in enumerate(ble5s):
                mode.connect(mode.ports["clk"], inst.pins["clk"])
                mode.connect(mode.ports["in"][6], inst.pins["in"][4])
                mode.connect(inst.pins["out"], mode.ports["out"][i])
                mode.connect(inst.pins["cout_fabric"], mode.ports["cout_fabric"])
            mode.connect(mode.ports["in"][3:0], ble5s[0].pins["in"][3:0])
            mode.connect(mode.ports["cin"], ble5s[0].pins["cin"], vpr_pack_patterns = ["carrychain"])
            mode.connect(mode.ports["in"][5:4], ble5s[1].pins["in"][3:2])
            mode.connect(mode.ports["in"][1:0], ble5s[1].pins["in"][1:0])
            mode.connect(ble5s[0].pins["cout"], ble5s[1].pins["cin"], vpr_pack_patterns = ["carrychain"])
            mode.connect(ble5s[1].pins["cout"], mode.ports["cout"], vpr_pack_patterns = ["carrychain"])
            mode.commit()

        # # mode (2): lut6x1
        # if True:
        #     mode = ubdr.build_mode("lut6x1")
        #     lut = mode.instantiate(context.primitives["lut6"], "i_lut6")
        #     ff = mode.instantiate(context.primitives["flipflop"], "i_flipflop")
        #     mode.connect(mode.ports["clk"], ff.pins["clk"])
        #     # FIXME: add LUT remap (LUT6 -> 2xLUT5 + MUXF6) and modify grady18.tmpl.v
        #     mode.connect(mode.ports["in"][3:0], lut.pins["in"][3:0])
        #     mode.connect(mode.ports["in"][7:6], lut.pins["in"][5:4])
        #     mode.connect(lut.pins["out"], ff.pins["D"], vpr_pack_patterns = ["lut6_dff"])
        #     mode.connect(lut.pins["out"], mode.ports["out"][0])
        #     mode.connect(ff.pins["Q"], mode.ports["out"][0])
        #     mode.commit()

        # logical view
        if "grady18" not in dont_add_logical_primitives:
            lbdr = ubdr.build_logical_counterpart(verilog_template = "grady18/grady18.tmpl.v")
            NetUtils.create_timing_arc(TimingArcType.comb_matrix, lbdr.ports["in"], lbdr.ports["out"])
            NetUtils.create_timing_arc(TimingArcType.comb_matrix, lbdr.ports["cin"], lbdr.ports["out"])
            NetUtils.create_timing_arc(TimingArcType.comb_matrix, lbdr.ports["in"], lbdr.ports["cout"])
            NetUtils.create_timing_arc(TimingArcType.comb_matrix, lbdr.ports["cin"], lbdr.ports["cout"])
            NetUtils.create_timing_arc(TimingArcType.comb_matrix, lbdr.ports["in"], lbdr.ports["cout_fabric"])
            NetUtils.create_timing_arc(TimingArcType.comb_matrix, lbdr.ports["cin"], lbdr.ports["cout_fabric"])
            NetUtils.create_timing_arc(TimingArcType.seq_start, lbdr.ports["clk"], lbdr.ports["out"])
            NetUtils.create_timing_arc(TimingArcType.seq_end, lbdr.ports["clk"], lbdr.ports["in"])
            NetUtils.create_timing_arc(TimingArcType.seq_end, lbdr.ports["clk"], lbdr.ports["cin"])
            lbdr.create_prog_port("prog_done", 1, PortDirection.input_)
            lbdr.create_prog_port("prog_data", 75, PortDirection.input_)

            lbdr.commit()

            # mark programming data bitmap
            # BLE5
            # mode (1): arith
            mode = ble5.modes["arith"]
            mode.prog_enable = ProgDataValue(ProgDataRange(34, 2), 1)

            adder = mode.instances["i_adder"]
            adder.prog_offset = 0
            adder.prog_parameters = { "CIN_MODE": ProgDataRange(32, 2) }

            conn = NetUtils.get_connection(adder.pins["s"], mode.ports["out"], skip_validations = True)
            conn.prog_enable = ProgDataValue(ProgDataRange(36, 1), 1)

            ff = mode.instances["i_flipflop"]
            ff.prog_offset = 0
            ff.prog_enable = None

            conn = NetUtils.get_connection(ff.pins["Q"], mode.ports["out"], skip_validations = True)
            conn.prog_enable = ProgDataValue(ProgDataRange(36, 1), 0)

            for i in range(2):
                lut = mode.instances["i_lut4", i]
                lut.prog_offset = 16 * i
                lut.prog_enable = None

            # mode (2): lut5
            mode = ble5.modes["lut5"]
            mode.prog_enable = ProgDataValue(ProgDataRange(34, 2), 2)

            lut = mode.instances["i_lut5"]
            lut.prog_offset = 0
            lut.prog_enable = None

            conn = NetUtils.get_connection(lut.pins["out"], mode.ports["out"], skip_validations = True)
            conn.prog_enable = ProgDataValue(ProgDataRange(36, 1), 1)

            ff = mode.instances["i_flipflop"]
            ff.prog_offset = 0
            ff.prog_enable = None

            conn = NetUtils.get_connection(ff.pins["Q"], mode.ports["out"], skip_validations = True)
            conn.prog_enable = ProgDataValue(ProgDataRange(36, 1), 0)

            # FLE8
            # mode (1): ble5x2
            mode = ubdr.module.modes["ble5x2"]
            mode.prog_enable = None

            for i in range(2):
                inst = mode.instances["i_ble5", i]
                inst.prog_offset = i * 37

                conn = NetUtils.get_connection(inst.pins["cout_fabric"], mode.ports["cout_fabric"],
                        skip_validations = True)
                conn.prog_enable = ProgDataValue(ProgDataRange(74, 1), i)

            # # mode (2): lut6
            # mode = ubdr.module.modes["lut6"]
            # mode.prog_enable = ProgDataValue(ProgDataRange(34, 39), ((3 << 37) + 3), ((3 << 37) + 3))

            lbdr.commit()
        else:
            ubdr.commit()

    @classmethod
    def register(cls, context, dont_add_logical_primitives = tuple()):
        """Register designs shipped with PRGA into ``context`` database.

        Args:
            context (`Context`):
        """
        if not isinstance(dont_add_logical_primitives, set):
            dont_add_logical_primitives = set(iter(dont_add_logical_primitives))

        # register built-in primitives: LUTs
        cls._register_luts(context, dont_add_logical_primitives)

        # register flipflops
        cls._register_flipflop(context, dont_add_logical_primitives)

        # register IOs
        cls._register_io(context, dont_add_logical_primitives)

        # register adder (user-only)
        cls._register_u_adder(context, dont_add_logical_primitives)

        # register FLE6
        cls._register_fle6(context, dont_add_logical_primitives)

        # register grady18 (FLE8 from Brett Grady, FPL'18)
        cls._register_grady18(context, dont_add_logical_primitives)

        # register simple buffers
        for name in ("prga_simple_buf", "prga_simple_bufr", "prga_simple_bufe", "prga_simple_bufre"):
            if name in dont_add_logical_primitives:
                continue
            buf = context._database[ModuleView.logical, name] = Module(name,
                    is_cell = True,
                    view = ModuleView.logical,
                    module_class = ModuleClass.aux,
                    verilog_template = "stdlib/{}.v".format(name))
            ModuleUtils.create_port(buf, "C", 1, PortDirection.input_, is_clock = True)
            if name in ("prga_simple_bufr", "prga_simple_bufre"):
                ModuleUtils.create_port(buf, "R", 1, PortDirection.input_)
            if name in ("prga_simple_bufe", "prga_simple_bufre"):
                ModuleUtils.create_port(buf, "E", 1, PortDirection.input_)
            ModuleUtils.create_port(buf, "D", 1, PortDirection.input_)
            ModuleUtils.create_port(buf, "Q", 1, PortDirection.output)

        # register auxiliary designs
        for d in ("prga_ram_1r1w", "prga_fifo", "prga_fifo_resizer", "prga_fifo_lookahead_buffer",
                "prga_fifo_adapter", "prga_byteaddressable_reg", "prga_tokenfifo", "prga_valrdy_buf"):
            context._database[ModuleView.logical, d] = Module(d,
                    is_cell = True,
                    view = ModuleView.logical,
                    module_class = ModuleClass.aux,
                    verilog_template = "stdlib/{}.v".format(d))
        for d in ("prga_ram_1r1w_dc", "prga_async_fifo", "prga_async_tokenfifo", "prga_clkdiv"):
            context._database[ModuleView.logical, d] = Module(d,
                    is_cell = True,
                    view = ModuleView.logical,
                    module_class = ModuleClass.aux,
                    verilog_template = "cdclib/{}.v".format(d))

        # module dependencies
        ModuleUtils.instantiate(context._database[ModuleView.logical, "prga_fifo"],
                context._database[ModuleView.logical, "prga_ram_1r1w"], "ram")
        ModuleUtils.instantiate(context._database[ModuleView.logical, "prga_fifo"],
                context._database[ModuleView.logical, "prga_fifo_lookahead_buffer"], "buffer")
        ModuleUtils.instantiate(context._database[ModuleView.logical, "prga_fifo_resizer"],
                context._database[ModuleView.logical, "prga_fifo_lookahead_buffer"], "buffer")
        ModuleUtils.instantiate(context._database[ModuleView.logical, "prga_fifo_adapter"],
                context._database[ModuleView.logical, "prga_fifo_lookahead_buffer"], "buffer")
        ModuleUtils.instantiate(context._database[ModuleView.logical, "prga_async_fifo"],
                context._database[ModuleView.logical, "prga_ram_1r1w_dc"], "ram")
        ModuleUtils.instantiate(context._database[ModuleView.logical, "prga_async_fifo"],
                context._database[ModuleView.logical, "prga_fifo_lookahead_buffer"], "buffer")

        # add headers
        context._add_verilog_header("prga_utils.vh", "stdlib/include/prga_utils.tmpl.vh")
