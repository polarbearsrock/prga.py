// Automatically generated by PRGA's RTL generator
`timescale 1ns/1ps
module prga_async_fifo #(
    parameter DEPTH_LOG2 = 1,
    parameter DATA_WIDTH = 32,
    parameter LOOKAHEAD = 0,
    parameter DO_SYNC_RST = 0
) (
    input wire [0:0] wclk,
    input wire [0:0] wrst,
    output wire [0:0] full,
    input wire [0:0] wr,
    input wire [DATA_WIDTH - 1:0] din,

    input wire [0:0] rclk,
    input wire [0:0] rrst,
    output wire [0:0] empty,
    input wire [0:0] rd,
    output wire [DATA_WIDTH - 1:0] dout
    );

    // Assumption: wrst and rrst are both "async assertion, sync deassertion"
    wire wrst_sync, rrst_sync;

    generate if (DO_SYNC_RST) begin
        reg wrst_f, rrst_f;

        // ASYNC assertion!
        always @(posedge wclk or posedge wrst) begin
            if (wrst) begin
                wrst_f <= 1'b1;
            end else begin
                wrst_f <= 1'b0;
            end
        end

        // ASYNC assertion!
        always @(posedge rclk or posedge rrst) begin
            if (rrst) begin
                rrst_f <= 1'b1;
            end else begin
                rrst_f <= 1'b0;
            end
        end

        assign wrst_sync = wrst_f;
        assign rrst_sync = rrst_f;
    end else begin
        assign wrst_sync = wrst;
        assign rrst_sync = rrst;
    end endgenerate

    // counters
    reg [DEPTH_LOG2:0]  b_wptr_wclk, g_wptr_wclk, g_wptr_rclk_s0, g_wptr_rclk_s1, b_wptr_rclk,
                        b_rptr_rclk, g_rptr_rclk, g_rptr_wclk_s0, g_rptr_wclk_s1, b_rptr_wclk;

    localparam FIFO_DEPTH = 1 << DEPTH_LOG2;
    wire empty_internal, rd_internal;
    wire [DATA_WIDTH - 1:0] ram_dout;

    prga_ram_1r1w_dc #(
        .DATA_WIDTH             (DATA_WIDTH)
        ,.ADDR_WIDTH            (DEPTH_LOG2)
        ,.RAM_ROWS              (FIFO_DEPTH)
        ,.REGISTER_OUTPUT       (1)
    ) ram (
        .wclk                   (wclk)
        ,.waddr                 (b_wptr_wclk[0 +: DEPTH_LOG2])
        ,.wdata                 (din)
        ,.we                    (~full && wr)
        ,.rclk                  (rclk)
        ,.raddr                 (b_rptr_rclk[0 +: DEPTH_LOG2])
        ,.rdata                 (ram_dout)
        );

    // gray-to-binary converting logic
    wire [DEPTH_LOG2:0] b_wptr_rclk_next, b_rptr_wclk_next;

    genvar i;
    generate
        for (i = 0; i < DEPTH_LOG2 + 1; i = i + 1) begin: b2g
            assign b_wptr_rclk_next[i] = ^(g_wptr_rclk_s1 >> i);
            assign b_rptr_wclk_next[i] = ^(g_rptr_wclk_s1 >> i);
        end
    endgenerate

    // write-domain
    always @(posedge wclk) begin
        if (wrst_sync) begin
            b_wptr_wclk <= 'b0;
            g_wptr_wclk <= 'b0;
            g_rptr_wclk_s0 <= 'b0;
            g_rptr_wclk_s1 <= 'b0;
            b_rptr_wclk <= 'b0;
        end else begin
            if (~full && wr) begin
                b_wptr_wclk <= b_wptr_wclk + 1;
            end

            g_wptr_wclk <= b_wptr_wclk ^ (b_wptr_wclk >> 1);
            g_rptr_wclk_s0 <= g_rptr_rclk;
            g_rptr_wclk_s1 <= g_rptr_wclk_s0;
            b_rptr_wclk <= b_rptr_wclk_next;
        end
    end

    // read-domain
    always @(posedge rclk) begin
        if (rrst_sync) begin
            b_rptr_rclk <= 'b0;
            g_rptr_rclk <= 'b0;
            g_wptr_rclk_s0 <= 'b0;
            g_wptr_rclk_s1 <= 'b0;
            b_wptr_rclk <= 'b0;
        end else begin
            if (~empty_internal && rd_internal) begin
                b_rptr_rclk <= b_rptr_rclk + 1;
            end

            g_rptr_rclk <= b_rptr_rclk ^ (b_rptr_rclk >> 1);
            g_wptr_rclk_s0 <= g_wptr_wclk;
            g_wptr_rclk_s1 <= g_wptr_rclk_s0;
            b_wptr_rclk <= b_wptr_rclk_next;
        end
    end

    assign full = wrst_sync || b_rptr_wclk == {~b_wptr_wclk[DEPTH_LOG2], b_wptr_wclk[0 +: DEPTH_LOG2]};
    assign empty_internal = rrst_sync || b_rptr_rclk == b_wptr_rclk;

    generate if (LOOKAHEAD) begin
        prga_fifo_lookahead_buffer #(
            .DATA_WIDTH             (DATA_WIDTH)
            ,.REVERSED              (0)
        ) buffer (
            .clk                    (rclk)
            ,.rst                   (rrst_sync)
            ,.empty_i               (empty_internal)
            ,.rd_i                  (rd_internal)
            ,.dout_i                (ram_dout)
            ,.empty                 (empty)
            ,.rd                    (rd)
            ,.dout                  (dout)
            );
    end else begin
        assign rd_internal = rd;
        assign dout = ram_dout;
        assign empty = empty_internal;
    end endgenerate

endmodule
