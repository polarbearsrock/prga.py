// Automatically generated by PRGA SimProj generator

`timescale 1ns/1ps
module {{ behav.name }}_tb_wrapper;

    localparam  bs_num_qwords       = {{ config.bs_num_qwords }},
                bs_word_size        = {{ config.bs_word_size }};

    // system control
    reg sys_clk, sys_rst;
    wire sys_success, sys_fail;

    // logging 
    reg             verbose;
    reg [0:256*8-1] waveform_dump;
    reg [31:0]      cycle_count, max_cycle_count;

    // testbench wires
    reg             tb_rst;

    // behavioral model wires
    {%- for name, port in behav.ports.items() %}
    wire {% if port.low is not none %}[{{ port.high - 1 }}:{{ port.low }}] {% endif %}behav_{{ name }};
    {%- endfor %}

    // FPGA implementation wires
    {%- for name, port in behav.ports.items() %}
        {%- if port.direction.name == 'output' %}
    wire {% if port.low is not none %}[{{ port.high - 1 }}:{{ port.low }}] {% endif %}impl_{{ name }};
        {%- endif %}
    {%- endfor %}

    // testbench
    {{ tb.name }} {% if tb.parameters %}#(
        {%- set comma0 = joiner(",") -%}
        {%- for k, v in tb.parameters.items() %}
        {{ comma0() }}.{{ k }}({{ v }})
        {%- endfor %}
    ) {% endif %}host (
        .sys_clk(sys_clk)
        ,.sys_rst(tb_rst)
        ,.sys_success(sys_success)
        ,.sys_fail(sys_fail)
        ,.cycle_count(cycle_count)
        {%- for name, port in behav.ports.items() %}
            {%- if port.direction.name == 'output' %}
        ,.{{ name }}(impl_{{ name }})
            {%- else %}
        ,.{{ name }}(behav_{{ port.name }})
            {%- endif %}
        {%- endfor %}
        );

`ifndef USE_POST_PAR_BEHAVIORAL_MODEL
    // behavioral model
    {{ behav.name }} {% if behav.parameters %}#(
        {%- set comma1 = joiner(",") -%}
        {%- for k, v in behav.parameters.items() %}
        {{ comma1() }}.{{ k }}({{ v }})
        {%- endfor %}
    ) {% endif %}behav (
        {%- set comma2 = joiner(",") -%}
        {%- for name in behav.ports %}
        {{ comma2() }}.{{ name }}(behav_{{ name }})
        {%- endfor %}
        );
`else
    // post-PAR simulation
    {{ behav.name }} behav (
        {%- set comma3 = joiner(",") -%}
        {%- for name, port in behav.ports.items() %}
            {%- if port.low is not none %}
                {%- for i in range(port.low, port.high) %}
        {{ comma3() }}.{{ "\\" ~ name ~ "[" ~ i ~ "]" }} (behav_{{ name ~ "[" ~ i ~ "]" }})
                {%- endfor %}
            {%- else %}
        {{ comma3() }}.{{ "\\" ~ name }} (behav_{{ name }})
            {%- endif %}
        {%- endfor %}
        );
`endif

    // test setup
    initial begin
        verbose = 1'b1;
        if ($test$plusargs("quiet")) begin
            verbose = 1'b0;
        end

        if ($value$plusargs("waveform_dump=%s", waveform_dump)) begin
            if (verbose)
                $display("[INFO] Dumping waveform: %s", waveform_dump);
            $dumpfile(waveform_dump);
            $dumpvars;
        end

        if (!$value$plusargs("max_cycle=%d", max_cycle_count)) begin
            max_cycle_count = 100_000;
        end

        if (verbose)
            $display("[INFO] Max cycle count: %d", max_cycle_count);

        sys_clk = 1'b0;
        sys_rst = 1'b0;
        #{{ (clk_period|default(10)) * 0.25 }} sys_rst = 1'b1;
        #{{ (clk_period|default(10)) * 100 }} sys_rst = 1'b0;
    end

    // system clock generator
    always #{{ (clk_period|default(10)) / 2.0 }} sys_clk = ~sys_clk;

    // cycle count tracking
    always @(posedge sys_clk) begin
        if (sys_rst) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
        end

        if (~sys_rst && (cycle_count % 1_000 == 0)) begin
            if (verbose)
                $display("[INFO] %3dK cycles passed", cycle_count / 1_000);
        end

        if (~sys_rst && (cycle_count >= max_cycle_count)) begin
            $display("[ERROR] max cycle count reached, killing simulation");
            $finish;
        end
    end

    // test result reporting
    always @* begin
        if (~tb_rst) begin
            if (sys_success) begin
                $display("[INFO] ********* all tests passed **********");
                $finish;
            end else if (sys_fail) begin
                $display("[INFO] ********* test failed **********");
                $finish;
            end
        end
    end

    // configuration (programming) control 
    localparam  INIT            = 3'd0,
                RESET           = 3'd1,
                PROGRAMMING     = 3'd2,
                PROG_STABLIZING = 3'd3,
                PROG_DONE       = 3'd4,
                TB_RESET        = 3'd5,
                IMPL_RUNNING    = 3'd6;

    reg [2:0]       state;
    reg [0:256*8-1] bs_file;
    reg [63:0]      cfg_m [0:bs_num_qwords];
    reg [bs_word_size-1:0]          cfg_i;
    wire [bs_word_size-1:0]         cfg_o;
    reg             cfg_e;
    reg             cfg_we, cfg_we_prev, cfg_we_o_prev;
    wire            cfg_we_o;
    reg [63:0]      cfg_progress;
    reg [31:0]      cfg_fragments;
    reg             fakeprog;

    // FPGA implementation
    {{ impl.name }} impl (
        .cfg_clk(sys_clk)
        ,.cfg_i(cfg_i)
        ,.cfg_e(cfg_e)
        ,.cfg_we(cfg_we)
        ,.cfg_we_o(cfg_we_o)
        ,.cfg_o(cfg_o)
        {%- for name, port in impl.ports.items() %}
            {%- if port.direction.name == 'output' %}
        ,.{{ name }}(impl_{{ port.name }})
            {%- else %}
        ,.{{ name }}(behav_{{ port.name }})
            {%- endif %}
        {%- endfor %}
        );

    // test setup
    initial begin
        state = INIT;
        cfg_e = 'b0;
        cfg_we = 'b0;

        if (!$value$plusargs("bitstream_memh=%s", bs_file)) begin
            if (verbose)
                $display("[ERROR] Missing required argument: bitstream_memh");
            $finish;
        end

        $readmemh(bs_file, cfg_m);
        cfg_m[bs_num_qwords] = 'b0;

        fakeprog = 'b0;
        if ($test$plusargs("fakeprog")) begin
            fakeprog = 'b1;
            {% for mem, addr, low, high in impl.config %}
            impl.{{ mem }} = cfg_m[{{ config.bs_num_qwords - 1 - addr }}][{{ high }}:{{ low }}];
            {%- endfor %}
        end
    end

    // configuration
    always @(posedge sys_clk) begin
        if (sys_rst) begin
            state <= RESET;
            cfg_progress <= 'b0;
        end else if (fakeprog) begin
            case (state)
                RESET:
                    state <= PROG_DONE;
                PROG_DONE:
                    state <= TB_RESET;
                TB_RESET:
                    state <= IMPL_RUNNING;
            endcase
        end else begin
            case (state)
                RESET:
                    state <= PROGRAMMING;
                PROGRAMMING: begin
                    if (cfg_we) begin
                        if (cfg_progress + bs_word_size >= bs_num_qwords * 64) begin
                            $display("[INFO] [Cycle %04d] Bitstream writing completed", cycle_count);
                            state <= PROG_STABLIZING;
                        end else begin
                            cfg_progress <= cfg_progress + bs_word_size;
                        end
                    end
                end
                PROG_STABLIZING: begin
                    if (cfg_fragments == 0) begin
                        $display("[INFO] [Cycle %04d] Bitstream loading completed", cycle_count);
                        state <= PROG_DONE;
                    end
                end
                PROG_DONE: begin
                    state <= TB_RESET;
                end
                TB_RESET: begin
                    state <= IMPL_RUNNING;
                end
            endcase
        end
    end
    
    always @(posedge sys_clk) begin
        if (sys_rst) begin
            cfg_we_prev <= 'b0;
            cfg_we_o_prev <= 'b0;
            cfg_fragments <= 'b0;
        end else begin
            cfg_we_prev <= cfg_we;
            cfg_we_o_prev <= cfg_we_o;

            if ((cfg_we && ~cfg_we_prev) && ~(cfg_we_o && ~cfg_we_o_prev)) begin
                cfg_fragments <= cfg_fragments + 1;
            end else if (~(cfg_we && ~cfg_we_prev) && (cfg_we_o && ~cfg_we_o_prev)) begin
                cfg_fragments <= cfg_fragments - 1;
            end
        end
    end

    always @* begin
        cfg_e = 1'b0;
        cfg_we = 1'b0;
        cfg_i = {cfg_m[cfg_progress / 64], cfg_m[cfg_progress / 64 + 1]} >> (128 - bs_word_size - cfg_progress % 64);
        tb_rst = sys_rst || state != IMPL_RUNNING;

        case (state)
            RESET: begin
                cfg_e = 'b1;
                cfg_we = 'b0;
            end
            PROGRAMMING: begin
                cfg_e = 'b1;
                cfg_we = cycle_count % 100;     // skip once every 100 cycles
            end
            PROG_STABLIZING: begin
                cfg_e = 'b1;
            end
        endcase
    end

    // progress tracking
    reg [7:0]       cfg_percentage;

    always @(posedge sys_clk) begin
        if (sys_rst) begin
            cfg_percentage <= 'b0;
        end else begin
            if (cfg_progress * 100 / bs_num_qwords / 64 > cfg_percentage) begin
                cfg_percentage <= cfg_percentage + 1;

                $display("[INFO] Programming progress: %02d%%", cfg_percentage + 1);
            end
        end
    end

    // output tracking
    always @(posedge sys_clk) begin
        if (~sys_rst && state == IMPL_RUNNING) begin
            {%- for name, port in behav.ports.items() %}
                {%- if port.direction.name == 'output' %}
            if (verbose && impl_{{ name }} !== behav_{{ name }}) begin
                $display("[WARNING] [Cycle %04d] Output mismatch: {{ name }}, impl (%h) != behav (%h)",
                    cycle_count, impl_{{ name }}, behav_{{ name }});
            end
                {%- endif %}
            {%- endfor %}
        end
    end

endmodule
