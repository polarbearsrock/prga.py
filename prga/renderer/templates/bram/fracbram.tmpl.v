// Automatically generated by PRGA's RTL generator
`timescale 1ns/1ps
module {{ module.name }} #(
    parameter   ADDR_WIDTH = {{ module.ports.waddr|length }}
    , parameter DATA_WIDTH = {{ module.ports.din|length }}
) (
    input wire [0:0] clk

    , input wire [ADDR_WIDTH - 1:0] waddr
    , input wire [0:0]              we
    , input wire [DATA_WIDTH - 1:0] din

    , input wire [ADDR_WIDTH - 1:0] raddr
    , output wire [DATA_WIDTH - 1:0] dout

    , input wire [0:0] prog_done
    , input wire [{{ module.ports.prog_data|length - 1 }}:0] prog_data
    );

    // non-fracturable memory core
    localparam  CORE_ADDR_WIDTH = {{ module.core_addr_width }};

    wire [CORE_ADDR_WIDTH - 1:0]    i_waddr, i_raddr;
    wire                            i_we, i_re;
    wire [DATA_WIDTH - 1:0]         i_bw, i_din, i_dout;

    {{ module.instances["i_ram"].model.name }} {% if module.instances["i_ram"].parameters %}#(
        {%- set comma = joiner(",") %}
        {%- for k, v in module.instances["i_ram"].parameters.items() %}
        {{ comma() }}.{{ k }} ({{ v }})
        {%- endfor %}
    ){% endif %}i_ram (
        .clk                        (clk)
        ,.rst                       (~prog_done)
        ,.waddr                     (i_waddr)
        ,.din                       (i_din)
        ,.we                        (i_we)
        ,.bw                        (i_bw)
        ,.raddr                     (i_raddr)
        ,.re                        (i_re)
        ,.dout                      (i_dout)
        );

    // Fracturable memory controller
    {{ module.instances["i_ctrl"].model.name }} {% if module.instances["i_ctrl"].parameters %}#(
        {%- set comma2 = joiner(",") %}
        {%- for k, v in module.instances["i_ctrl"].parameters.items() %}
        {{ comma2() }}.{{ k }} ({{ v }})
        {%- endfor %}
    ){% endif %}i_ctrl (
        .clk                        (clk)
        ,.u_waddr_i                 (waddr)
        ,.u_we_i                    (we)
        ,.u_din_i                   (din)
        ,.u_raddr_i                 (raddr)
        ,.u_dout_o                  (dout)
        ,.i_waddr_o                 (i_waddr)
        ,.i_we_o                    (i_we)
        ,.i_din_o                   (i_din)
        ,.i_bw_o                    (i_bw)
        ,.i_raddr_o                 (i_raddr)
        ,.i_re_o                    (i_re)
        ,.i_dout_i                  (i_dout)
        ,.prog_done                 (prog_done)
        ,.prog_data                 (prog_data)
        );

endmodule
