// Automatically generated by PRGA's RTL generator
`timescale 1ns/1ps
module prga_async_fifo #(
    parameter   DEPTH_LOG2 = 1
    , parameter DATA_WIDTH = 32
    , parameter LOOKAHEAD = 0
    , parameter ASYNC_RST = 0
) (
    // synchronous in `wclk` domain if ~ASYNC_RST
    // Assumption:  once `rst_n` is asserted, it must be held until
    //  `rst_n_echo_wclk` is asserted (see prga_async_fifo_ptr)
    input wire                      rst_n
    , output wire                   rst_n_rclk

    , input wire                    wclk
    , input wire                    wr
    , output wire                   full
    , output wire [DATA_WIDTH-1:0]  din

    , input wire                    rclk
    , input wire                    rd
    , output wire                   empty
    , output wire [DATA_WIDTH-1:0]  dout
    );

    // -- Forward Declaration --
    wire rd_internal, empty_internal;
    wire [DATA_WIDTH-1:0] dout_internal;

    // -- Pointers --
    wire [DEPTH_LOG2:0] wptr, rptr;

    prga_async_fifo_ptr #(
        .DEPTH_LOG2     (DEPTH_LOG2)
        ,.ASYNC_RST     (ASYNC_RST)
    ) i_ptr (
        .rst_n          (rst_n)
        ,.rst_n_rclk    (rst_n_rclk)
        ,.wclk          (wclk)
        ,.wr            (wr)
        ,.full          (full)
        ,.wptr          (wptr)
        ,.rclk          (rclk)
        ,.rd            (rd_internal)
        ,.empty         (empty_internal)
        ,.rptr          (rptr)
        );

    // -- Memory -- 
    localparam FIFO_DEPTH = 1 << DEPTH_LOG2;
    prga_ram_1r1w_dc #(
        .DATA_WIDTH         (DATA_WIDTH)
        ,.ADDR_WIDTH        (DEPTH_LOG2)
        ,.RAM_ROWS          (FIFO_DEPTH)
        ,.REGISTER_OUTPUT   (1)
    ) i_ram (
        .wclk           (wclk)
        ,.waddr         (wptr[0+:DEPTH_LOG2])
        ,.wdata         (din)
        ,.we            (~full && wr)
        ,.rclk          (rclk)
        ,.raddr         (rptr[0+:DEPTH_LOG2])
        ,.rdata         (dout_internal)    
        );

    // -- Lookahead buffer --
    generate if (LOOKAHEAD) begin
        prga_fifo_lookahead_buffer #(
            .DATA_WIDTH     (DATA_WIDTH)
            ,.REVERSED      (0)
        ) i_buffer (
            .clk            (rclk)
            ,.rst           (~rst_n_rclk)
            ,.empty_i       (empty_internal)
            ,.rd_i          (rd_internal)
            ,.dout_i        (dout_internal)
            ,.empty         (empty)
            ,.rd            (rd)
            ,.dout          (dout)
            );
    end else begin
        assign rd_internal = rd;
        assign dout = dout_internal;
        assign empty = empty_internal;
    end endgenerate

endmodule
