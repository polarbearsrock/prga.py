# Automatically generated by PRGA Simproj generator
# ----------------------------------------------------------------------------
# -- Binaries ----------------------------------------------------------------
# ----------------------------------------------------------------------------
PYTHON ?= python
YOSYS ?= yosys
VPR ?= vpr
GENFASM ?= genfasm

{# compiler options #}
{%- if compiler == 'iverilog' %}
COMP ?= iverilog
FLAGS := -g2005 -gspecify
{%- elif compiler == 'vcs' %}
COMP ?= vcs
FLAGS := -full64 -v2005
{%- endif %}

# ----------------------------------------------------------------------------
# -- Inputs ------------------------------------------------------------------
# ----------------------------------------------------------------------------
TESTBENCH_WRAPPER := {{ testbench_wrapper }}

TARGET := {{ target.name }}
TARGET_SRCS := {{ target.sources|join(' ') }}
TARGET_FLAGS :={% for inc in target.includes %} {% if compiler == 'iverilog' %}-I{{ inc }}{% elif compiler == 'vcs' %}+incdir+{{ inc }}{% endif %}{% endfor %}
TARGET_FLAGS +={% for macro in target.defines %} {% if compiler == 'iverilog' %}-D{{ macro }}{% elif compiler == 'vcs' %}+define+{{ macro }}{% endif %}{% endfor %}

HOST := {{ host.name }}
HOST_SRCS := {{ host.sources|join(' ') }}
HOST_FLAGS :={% for inc in host.includes %} {% if compiler == 'iverilog' %}-I{{ inc }}{% elif compiler == 'vcs' %}+incdir+{{ inc }}{% endif %}{% endfor %}
HOST_FLAGS +={% for macro in host.defines %} {% if compiler == 'iverilog' %}-D{{ macro }}{% elif compiler == 'vcs' %}+define+{{ macro }}{% endif %}{% endfor %}
HOST_ARGS :={% for arg in host.args %} +{{ arg }}{% endfor %}

CTX := {{ context }}

YOSYS_SCRIPT := {{ yosys_script }}

VPR_CHAN_WIDTH := {{ vpr.channel_width }}
VPR_ARCHDEF := {{ vpr.archdef }}
VPR_RRGRAPH := {{ vpr.rrgraph }}
VPR_IOBINDING := {{ vpr.io_binding }}
{% for f in rtl %}
	{%- if loop.first %}
FPGA_RTL := {{ f }}
	{%- else %}
FPGA_RTL += {{ f }}
	{%- endif %}
{%- endfor %}

# ----------------------------------------------------------------------------
# -- Outputs -----------------------------------------------------------------
# ----------------------------------------------------------------------------
SYNTHESIS_RESULT := $(TARGET).blif
SYNTHESIS_LOG := $(TARGET).synth.log
PACK_RESULT := $(TARGET).net
PACK_LOG := $(TARGET).pack.log
PLACE_RESULT := $(TARGET).place
PLACE_LOG := $(TARGET).place.log
ROUTE_RESULT := $(TARGET).route
ROUTE_LOG := $(TARGET).route.log
FASM_RESULT := $(TARGET).fasm
FASM_LOG := $(TARGET).fasm.log
BITGEN_RESULT := $(TARGET).memh
SIM := sim_$(TARGET)
SIM_LOG := $(TARGET).log
SIM_WAVEFORM := $(TARGET).vpd

OUTPUTS := $(SYNTHESIS_RESULT)
OUTPUTS += $(PACK_RESULT)
OUTPUTS += $(PLACE_RESULT)
OUTPUTS += $(ROUTE_RESULT)
OUTPUTS += $(FASM_RESULT)
OUTPUTS += $(BITGEN_RESULT)
OUTPUTS += $(SIM)

LOGS := $(SYNTHESIS_LOG)
LOGS += $(PACK_LOG)
LOGS += $(PLACE_LOG)
LOGS += $(ROUTE_LOG)
LOGS += $(FASM_LOG)
LOGS += $(SIM_LOG)

JUNKS := csrc *.daidir ucli.key vpr_stdout.log *.rpt
JUNKS += *.vpd DVEfiles opendatabase.log

# ----------------------------------------------------------------------------
# -- Phony rules -------------------------------------------------------------
# ----------------------------------------------------------------------------
.PHONY: verify synth pack bind place route fasm bitgen compile waveform clean cleanlog cleanall makefile_validation_ disp
verify: $(SIM_LOG) makefile_validation_
	@echo '********************************************'
	@echo '**                 Report                 **'
	@echo '********************************************'
	@grep "all tests passed" $(SIM_LOG) || (echo " (!) verification failed" && exit 1)

synth: $(SYNTHESIS_RESULT) makefile_validation_

pack: $(PACK_RESULT) makefile_validation_

place: $(PLACE_RESULT) makefile_validation_

route: $(ROUTE_RESULT) makefile_validation_

fasm: $(FASM_RESULT) makefile_validation_

bitgen: $(BITGEN_RESULT) makefile_validation_

compile: $(SIM) makefile_validation_

waveform: $(SIM_WAVEFORM) makefile_validation_

clean: makefile_validation_
	rm -rf $(JUNKS)

cleanlog: makefile_validation_
	rm -rf $(LOGS)

cleanall: clean cleanlog
	rm -rf $(OUTPUTS)

disp: $(SYNTHESIS_RESULT) $(PACK_RESULT) $(PLACE_RESULT) $(ROUTE_RESULT) makefile_validation_
	$(VPR) $(VPR_ARCHDEF) $(SYNTHESIS_RESULT) --circuit_format eblif --net_file $(PACK_RESULT) \
		--place_file $(PLACE_RESULT) --route_file $(ROUTE_RESULT) --analysis \
		--route_chan_width $(VPR_CHAN_WIDTH) --read_rr_graph $(VPR_RRGRAPH) --disp on

{# compiler options #}
{%- if compiler not in ['iverilog', 'vcs'] %}
makefile_validation_:
	echo "Unknown compiler option: {{ compiler }}. This generated Makefile is invalid"
	exit 1
{%- else %}
makefile_validation_: ;
{%- endif %}

# ----------------------------------------------------------------------------
# -- Regular rules -----------------------------------------------------------
# ----------------------------------------------------------------------------
$(SYNTHESIS_RESULT): $(TARGET_SRCS) $(YOSYS_SCRIPT)
	$(YOSYS) -s $(YOSYS_SCRIPT) \
		| tee $(SYNTHESIS_LOG)

$(PACK_RESULT): $(VPR_ARCHDEF) $(SYNTHESIS_RESULT)
	$(VPR) $^ --circuit_format eblif --pack --net_file $@ --constant_net_method route \
		| tee $(PACK_LOG)

$(PLACE_RESULT): $(VPR_ARCHDEF) $(SYNTHESIS_RESULT) $(PACK_RESULT) $(VPR_IOBINDING)
	$(VPR) $(VPR_ARCHDEF) $(SYNTHESIS_RESULT) --circuit_format eblif --constant_net_method route \
		--net_file $(PACK_RESULT) \
		--place --place_file $@ --fix_pins $(VPR_IOBINDING) \
		--place_delay_model delta_override --place_chan_width $(VPR_CHAN_WIDTH) \
		| tee $(PLACE_LOG)

$(ROUTE_RESULT): $(VPR_ARCHDEF) $(SYNTHESIS_RESULT) $(VPR_RRGRAPH) $(PACK_RESULT) $(PLACE_RESULT)
	$(VPR) $(VPR_ARCHDEF) $(SYNTHESIS_RESULT) --circuit_format eblif --constant_net_method route \
		--net_file $(PACK_RESULT) --place_file $(PLACE_RESULT) \
		--route --route_file $@ --route_chan_width $(VPR_CHAN_WIDTH) --read_rr_graph $(VPR_RRGRAPH) \
		| tee $(ROUTE_LOG)

$(FASM_RESULT): $(VPR_ARCHDEF) $(SYNTHESIS_RESULT) $(VPR_RRGRAPH) $(PACK_RESULT) $(PLACE_RESULT) $(ROUTE_RESULT)
	$(GENFASM) $(VPR_ARCHDEF) $(SYNTHESIS_RESULT) --circuit_format eblif --analysis \
		--net_file $(PACK_RESULT) --place_file $(PLACE_RESULT) --route_file $(ROUTE_RESULT) \
		--route_chan_width $(VPR_CHAN_WIDTH) --read_rr_graph $(VPR_RRGRAPH) \
		| tee $(FASM_LOG)

$(BITGEN_RESULT): $(CTX) $(FASM_RESULT)
	$(PYTHON) -m prga_tools.bitchain.bitgen $^ $@

$(SIM): $(TESTBENCH_WRAPPER) $(TARGET_SRCS) $(HOST_SRCS) $(FPGA_RTL)
	$(COMP) $(FLAGS) $(HOST_FLAGS) $(TARGET_FLAGS) $< -o $@ $(addprefix -v ,$^)

$(SIM_LOG): $(SIM) $(BITGEN_RESULT)
	./$< $(HOST_ARGS) +bitstream_memh=$(BITGEN_RESULT) | tee $@

$(SIM_WAVEFORM): $(SIM) $(BITGEN_RESULT)
	./$< $(HOST_ARGS) +bitstream_memh=$(BITGEN_RESULT) +waveform_dump=$@
