// Automatically generated by PRGA's RTL generator
`timescale 1ns/1ps

/*
* Ctrl Core.
*/

`include "prga_system.vh"

module prga_ctrl #(
    parameter   DECOUPLED = 1
) (
    input wire                                  clk,
    input wire                                  rst_n,

    // == Generic CREG Interface ==============================================
    output reg                                  creg_req_rdy,
    input wire                                  creg_req_val,
    input wire [`PRGA_CREG_ADDR_WIDTH-1:0]      creg_req_addr,
    input wire [`PRGA_CREG_DATA_BYTES-1:0]      creg_req_strb,
    input wire [`PRGA_CREG_DATA_WIDTH-1:0]      creg_req_data,

    input wire                                  creg_resp_rdy,
    output reg                                  creg_resp_val,
    output reg [`PRGA_CREG_DATA_WIDTH-1:0]      creg_resp_data,

    // == Key Ctrl Inputs/Outputs =============================================
    output wire                                 aclk,
    output reg                                  arst_n,

    output reg                                  app_en,
    output reg                                  app_en_aclk,
    output wire [`PRGA_CREG_DATA_WIDTH-1:0]     app_features,

    // == CTRL <-> PROG =======================================================
    output reg                                  prog_rst_n,
    input wire [`PRGA_PROG_STATUS_WIDTH-1:0]    prog_status,

    input wire                                  prog_req_rdy,
    output wire                                 prog_req_val,
    output wire [`PRGA_CREG_ADDR_WIDTH-1:0]     prog_req_addr,
    output wire [`PRGA_CREG_DATA_BYTES-1:0]     prog_req_strb,
    output wire [`PRGA_CREG_DATA_WIDTH-1:0]     prog_req_data,

    input wire                                  prog_resp_val,
    output wire                                 prog_resp_rdy,
    input wire                                  prog_resp_err,
    input wire [`PRGA_CREG_DATA_WIDTH-1:0]      prog_resp_data,

    // == CTRL <-> SAX ========================================================
    input wire                                  sax_rdy,
    output reg                                  sax_val,
    output reg [`PRGA_SAX_DATA_WIDTH-1:0]       sax_data,

    output reg                                  asx_rdy,
    input wire                                  asx_val,
    input wire [`PRGA_ASX_DATA_WIDTH-1:0]       asx_data
    );

    // ========================================================================
    // -- Val/Rdy Buffer ------------------------------------------------------
    // ========================================================================
    reg [`PRGA_PROG_STATUS_WIDTH-1:0]           prog_status_f;

    always @(posedge clk) begin
        if (~rst_n) begin
            prog_status_f <= `PRGA_PROG_STATUS_STANDBY;
        end else begin
            prog_status_f <= prog_status;
        end
    end

    wire prog_req_rdy_f;
    reg  prog_req_val_p;
    reg  [`PRGA_CREG_ADDR_WIDTH-1:0]         prog_req_addr_p;
    reg  [`PRGA_CREG_DATA_BYTES-1:0]         prog_req_strb_p;
    reg  [`PRGA_CREG_DATA_WIDTH-1:0]         prog_req_data_p;

    prga_valrdy_buf #(
        .REGISTERED         (DECOUPLED)
        ,.DECOUPLED         (DECOUPLED)
        ,.DATA_WIDTH        (
            `PRGA_CREG_ADDR_WIDTH
            + `PRGA_CREG_DATA_BYTES
            + `PRGA_CREG_DATA_WIDTH
        )
    ) prog_req_valrdy_buf (
        .clk                (clk)
        ,.rst               (~rst_n)
        ,.rdy_o             (prog_req_rdy_f)
        ,.val_i             (prog_req_val_p)
        ,.data_i            ({
            prog_req_addr_p
            , prog_req_strb_p
            , prog_req_data_p
        })
        ,.rdy_i             (prog_req_rdy)
        ,.val_o             (prog_req_val)
        ,.data_o            ({
            prog_req_addr
            , prog_req_strb
            , prog_req_data
        })
        );

    wire prog_resp_val_f;
    reg  prog_resp_rdy_p;
    wire                                      prog_resp_err_f;
    wire [`PRGA_CREG_DATA_WIDTH-1:0]          prog_resp_data_f;

    prga_valrdy_buf #(
        .REGISTERED         (DECOUPLED)
        ,.DECOUPLED         (DECOUPLED)
        ,.DATA_WIDTH        (1 + `PRGA_CREG_DATA_WIDTH)
    ) prog_resp_valrdy_buf (
        .clk                (clk)
        ,.rst               (~rst_n)
        ,.rdy_o             (prog_resp_rdy)
        ,.val_i             (prog_resp_val)
        ,.data_i            ({
            prog_resp_err
            , prog_resp_data
        })
        ,.rdy_i             (prog_resp_rdy_p)
        ,.val_o             (prog_resp_val_f)
        ,.data_o            ({
            prog_resp_err_f
            , prog_resp_data_f
        })
        );

    // ========================================================================
    // -- Application Clock & Reset -------------------------------------------
    // ========================================================================

    reg [`PRGA_CLKDIV_WIDTH-1:0]        aclk_div_next;
    wire [`PRGA_CLKDIV_WIDTH-1:0]       aclk_div;

    prga_clkdiv #(
        .COUNTER_WIDTH                  (`PRGA_CLKDIV_WIDTH)
    ) i_clkdiv (
        .clk                            (clk)
        ,.rst                           (~rst_n)
        ,.div_factor_i                  (aclk_div_next)
        ,.div_factor_we_i               (1'b1)
        ,.div_factor_o                  (aclk_div)
        ,.divclk                        (aclk)
        );

    always @(posedge aclk or negedge rst_n) begin
        if (~rst_n) begin
            arst_n <= 1'b0;
        end else begin
            arst_n <= 1'b1;
        end
    end

    // ========================================================================
    // -- Configuration Reset -------------------------------------------------
    // ========================================================================

    reg                                 prog_rst_n_set;

    always @(posedge clk) begin
        if (~rst_n || prog_rst_n_set) begin
            prog_rst_n <= 1'b0;
        end else if (prog_status_f == `PRGA_PROG_STATUS_STANDBY) begin
            prog_rst_n <= 1'b1;
        end
    end

    // ========================================================================
    // -- CREG (Configuration Registers) --------------------------------------
    // ========================================================================

    // == Shared Variables ==
    reg [`PRGA_CREG_DATA_WIDTH-1:0]     creg_update_data;
    reg [`PRGA_CREG_DATA_BYTES-1:0]     creg_update_strb;

    // == Bitstream ID ==
    reg bitstream_id_update;
    wire [`PRGA_CREG_DATA_WIDTH-1:0]    bitstream_id;

    prga_byteaddressable_reg #(
        .NUM_BYTES                      (`PRGA_CREG_DATA_BYTES)
    ) i_bitstream_id (
        .clk                            (clk)
        ,.rst                           (~rst_n)
        ,.wr                            (bitstream_id_update)
        ,.mask                          (creg_update_strb)
        ,.din                           (creg_update_data)
        ,.dout                          (bitstream_id)
        );

    // == Error Flags ==
    reg eflags_force, eflags_set;
    reg [`PRGA_CREG_DATA_WIDTH-1:0]     eflags_set_mask;
    wire [`PRGA_CREG_DATA_WIDTH-1:0]    eflags;

    prga_byteaddressable_reg #(
        .NUM_BYTES                      (`PRGA_CREG_DATA_BYTES)
    ) i_eflags (
        .clk                            (clk)
        ,.rst                           (~rst_n)
        ,.wr                            (eflags_force || eflags_set)
        ,.mask                          (eflags_force ? creg_update_strb : {`PRGA_CREG_DATA_BYTES {1'b1} })
        ,.din                           (eflags_force ? creg_update_data : (eflags | eflags_set_mask))
        ,.dout                          (eflags)
        );

    // == APP Features ==
    reg app_features_update;

    prga_byteaddressable_reg #(
        .NUM_BYTES                      (`PRGA_CREG_DATA_BYTES)
    ) i_app_features (
        .clk                            (clk)
        ,.rst                           (~rst_n)
        ,.wr                            (app_features_update)
        ,.mask                          (creg_update_strb)
        ,.din                           (creg_update_data)
        ,.dout                          (app_features)
        );

    // ========================================================================
    // -- Application Enable --------------------------------------------------
    // ========================================================================

    reg app_en_set;

    always @(posedge clk) begin
        if (~rst_n || (|eflags || prog_status_f != `PRGA_PROG_STATUS_DONE)) begin
            app_en <= 1'b0;
        end else if (app_en_set) begin
            app_en <= 1'b1;
        end
    end

    reg app_en_aclk_s0;

    always @(posedge aclk) begin
        if (~arst_n) begin
            {app_en_aclk, app_en_aclk_s0} <= 2'b0;
        end else begin
            {app_en_aclk, app_en_aclk_s0} <= {app_en_aclk_s0, app_en};
        end
    end

    // ========================================================================
    // -- CREG Access Reordering ----------------------------------------------
    // ========================================================================

    localparam  CREG_TOKEN_WIDTH        = 3;
    localparam  CREG_TOKEN_INVAL        = 3'h0,
                CREG_TOKEN_CTRL_READ    = 3'h1,
                CREG_TOKEN_PROG_READ    = 3'h2,
                CREG_TOKEN_SAX_READ     = 3'h3,
                CREG_TOKEN_CTRL_WRITE   = 3'h5,
                CREG_TOKEN_PROG_WRITE   = 3'h6,
                CREG_TOKEN_SAX_WRITE    = 3'h7;

    wire i_tokenq_full, i_tokenq_empty;
    reg i_tokenq_wr, i_tokenq_rd;
    wire [CREG_TOKEN_WIDTH-1:0] i_tokenq_dout;
    reg [CREG_TOKEN_WIDTH-1:0] i_tokenq_din;

    prga_fifo #(
        .DATA_WIDTH                     (CREG_TOKEN_WIDTH)
        ,.DEPTH_LOG2                    (6)
        ,.LOOKAHEAD                     (1)
    ) i_tokenq (
        .clk                            (clk)
        ,.rst                           (~rst_n)
        ,.full                          (i_tokenq_full)
        ,.wr                            (i_tokenq_wr)
        ,.din                           (i_tokenq_din)
        ,.empty                         (i_tokenq_empty)
        ,.rd                            (i_tokenq_rd)
        ,.dout                          (i_tokenq_dout)
        );

    wire i_ctrldataq_full, i_ctrldataq_empty;
    reg i_ctrldataq_wr, i_ctrldataq_rd;
    wire [`PRGA_CREG_DATA_WIDTH-1:0] i_ctrldataq_dout;
    reg [`PRGA_CREG_DATA_WIDTH-1:0] i_ctrldataq_din;

    prga_fifo #(
        .DATA_WIDTH                     (`PRGA_CREG_DATA_WIDTH)
        ,.DEPTH_LOG2                    (2)
        ,.LOOKAHEAD                     (1)
    ) i_ctrldataq (
        .clk                            (clk)
        ,.rst                           (~rst_n)
        ,.full                          (i_ctrldataq_full)
        ,.wr                            (i_ctrldataq_wr)
        ,.din                           (i_ctrldataq_din)
        ,.empty                         (i_ctrldataq_empty)
        ,.rd                            (i_ctrldataq_rd)
        ,.dout                          (i_ctrldataq_dout)
        );

    // ========================================================================
    // -- Request Pipeline ----------------------------------------------------
    // ========================================================================

    // 2 Stages:
    //
    //  T (Token acquisition):  Acquire a token in token Q
    //  X (Execute):            Send PROG/SAX request, or execute CTRL read/write

    reg stall_req_t, stall_req_x;

    // -- T stage variables --
    reg                                 val_req_t;
    reg [`PRGA_CREG_ADDR_WIDTH-1:0]     addr_req_t;
    reg [`PRGA_CREG_DATA_WIDTH-1:0]     data_req_t;
    reg [`PRGA_CREG_DATA_BYTES-1:0]     strb_req_t;
    reg                                 val_req_x_next;

    // -- X stage variables --
    reg                                 app_en_x;
    reg                                 val_req_x;
    reg [`PRGA_CREG_ADDR_WIDTH-1:0]     addr_req_x;
    reg [`PRGA_CREG_DATA_WIDTH-1:0]     data_req_x;
    reg [`PRGA_CREG_DATA_BYTES-1:0]     strb_req_x;

    // == T Stage =============================================================

    // == Register Inputs ==
    always @(posedge clk) begin
        if (~rst_n) begin
            val_req_t       <= 1'b0;
            addr_req_t      <= {`PRGA_CREG_ADDR_WIDTH {1'b0} };
            data_req_t      <= {`PRGA_CREG_DATA_WIDTH {1'b0} };
            strb_req_t      <= {`PRGA_CREG_DATA_BYTES {1'b0} };
        end else if (creg_req_rdy && creg_req_val) begin
            val_req_t       <= 1'b1;
            addr_req_t      <= creg_req_addr;
            data_req_t      <= creg_req_data;
            strb_req_t      <= creg_req_strb;
        end else if (~stall_req_t) begin
            val_req_t       <= 1'b0;
        end
    end

    always @* begin
        creg_req_rdy = rst_n && (~val_req_t || ~stall_req_t);
    end

    // == Main Logic ==
    always @* begin
        i_tokenq_wr = 1'b0;
        i_tokenq_din = CREG_TOKEN_INVAL;
        stall_req_t = stall_req_x;
        val_req_x_next = 1'b0;

        if (val_req_t && ~stall_req_x) begin
            i_tokenq_wr = 1'b1;
            stall_req_t = i_tokenq_full;
            val_req_x_next = ~i_tokenq_full;

            if (addr_req_t[`PRGA_CREG_ADDR_WIDTH-1]) begin
                // CTRL/PROG
                case (addr_req_t)
                    `PRGA_CREG_ADDR_BITSTREAM_ID,
                    `PRGA_CREG_ADDR_EFLAGS,
                    `PRGA_CREG_ADDR_ACLK_DIV,
                    `PRGA_CREG_ADDR_PROG_STATUS: begin
                        if (|strb_req_t) begin
                            i_tokenq_din = CREG_TOKEN_CTRL_WRITE;
                        end else begin
                            i_tokenq_din = CREG_TOKEN_CTRL_READ;
                        end
                    end
                    `PRGA_CREG_ADDR_APP_FEATURES: begin
                        if (|strb_req_t) begin
                            i_tokenq_din = CREG_TOKEN_SAX_WRITE;
                        end else begin
                            i_tokenq_din = CREG_TOKEN_CTRL_READ;
                        end
                    end
                    `PRGA_CREG_ADDR_APP_RST,
                    `PRGA_CREG_ADDR_TIMEOUT: begin
                        if (|strb_req_t) begin
                            i_tokenq_din = CREG_TOKEN_SAX_WRITE;
                        end else begin
                            i_tokenq_din = CREG_TOKEN_SAX_READ;
                        end
                    end
                    default: begin
                        if (|strb_req_t) begin
                            i_tokenq_din = CREG_TOKEN_PROG_WRITE;
                        end else begin
                            i_tokenq_din = CREG_TOKEN_PROG_READ;
                        end
                    end
                endcase
            end else if (app_en && app_features[`PRGA_APP_UREG_EN_INDEX]) begin
                if (|strb_req_t) begin
                    i_tokenq_din = CREG_TOKEN_SAX_WRITE;
                end else begin
                    i_tokenq_din = CREG_TOKEN_SAX_READ;
                end
            end else begin
                i_tokenq_din = CREG_TOKEN_CTRL_WRITE;
            end
        end
    end

    // == X Stage =============================================================

    // == Register Data from T Stage ==
    always @(posedge clk) begin
        if (~rst_n) begin
            app_en_x    <= 1'b0;
            val_req_x   <= 1'b0;
            addr_req_x  <= {`PRGA_CREG_ADDR_WIDTH {1'b0} };
            data_req_x  <= {`PRGA_CREG_DATA_WIDTH {1'b0} };
            strb_req_x  <= {`PRGA_CREG_DATA_BYTES {1'b0} };
        end else if (~stall_req_x) begin
            app_en_x    <= app_en && app_features[`PRGA_APP_UREG_EN_INDEX];
            val_req_x   <= val_req_x_next;
            addr_req_x  <= addr_req_t;
            data_req_x  <= data_req_t;
            strb_req_x  <= strb_req_t;
        end
    end

    // == Main Logic ==
    always @* begin
        i_ctrldataq_wr = 1'b0;
        i_ctrldataq_din = {`PRGA_CREG_DATA_WIDTH {1'b0} };
        stall_req_x = 1'b1;

        prog_req_val_p = 1'b0;
        prog_req_addr_p = {`PRGA_CREG_ADDR_WIDTH {1'b0} };
        prog_req_data_p = {`PRGA_CREG_DATA_WIDTH {1'b0} };
        prog_req_strb_p = {`PRGA_CREG_DATA_BYTES {1'b0} };
        sax_val = 1'b0;
        sax_data = {`PRGA_SAX_DATA_WIDTH {1'b0} };

        aclk_div_next = aclk_div;
        prog_rst_n_set = 1'b0;
        creg_update_data = {`PRGA_CREG_DATA_WIDTH {1'b0} };
        creg_update_strb = {`PRGA_CREG_DATA_BYTES {1'b0} };
        bitstream_id_update = 1'b0;
        eflags_force = 1'b0;
        app_features_update = 1'b0;
        app_en_set = 1'b0;

        if (val_req_x) begin
            if (addr_req_x[`PRGA_CREG_ADDR_WIDTH-1]) begin
                if (|strb_req_x) begin
                    case (addr_req_x)
                        `PRGA_CREG_ADDR_BITSTREAM_ID: begin
                            creg_update_data = data_req_x;
                            creg_update_strb = strb_req_x;
                            bitstream_id_update = 1'b1;
                            stall_req_x = 1'b0;
                        end
                        `PRGA_CREG_ADDR_EFLAGS: begin
                            creg_update_data = data_req_x;
                            creg_update_strb = strb_req_x;
                            eflags_force = 1'b1;
                            stall_req_x = 1'b0;
                        end
                        `PRGA_CREG_ADDR_ACLK_DIV: begin
                            aclk_div_next = data_req_x[0+:`PRGA_CLKDIV_WIDTH];
                            stall_req_x = 1'b0;
                        end
                        `PRGA_CREG_ADDR_PROG_STATUS: begin
                            prog_rst_n_set = 1'b1;
                            stall_req_x = 1'b0;
                        end
                        `PRGA_CREG_ADDR_APP_FEATURES: begin
                            creg_update_data = data_req_x;
                            creg_update_strb = strb_req_x;
                            app_features_update = 1'b1;

                            sax_val = 1'b1;
                            sax_data[`PRGA_SAX_MSGTYPE_INDEX] = `PRGA_SAX_MSGTYPE_CREG_WRITE;
                            sax_data[`PRGA_SAX_CREG_STRB_INDEX] = strb_req_x;
                            sax_data[`PRGA_SAX_CREG_ADDR_INDEX] = addr_req_x;
                            sax_data[`PRGA_SAX_CREG_DATA_INDEX] = data_req_x;
                            stall_req_x = ~sax_rdy;
                        end
                        `PRGA_CREG_ADDR_APP_RST: begin
                            app_en_set = prog_status_f == `PRGA_PROG_STATUS_DONE && ~|eflags;

                            sax_val = 1'b1;
                            sax_data[`PRGA_SAX_MSGTYPE_INDEX] = `PRGA_SAX_MSGTYPE_CREG_WRITE;
                            sax_data[`PRGA_SAX_CREG_STRB_INDEX] = strb_req_x;
                            sax_data[`PRGA_SAX_CREG_ADDR_INDEX] = addr_req_x;
                            sax_data[`PRGA_SAX_CREG_DATA_INDEX] = data_req_x;
                            stall_req_x = ~sax_rdy;
                        end
                        `PRGA_CREG_ADDR_TIMEOUT: begin
                            sax_val = 1'b1;
                            sax_data[`PRGA_SAX_MSGTYPE_INDEX] = `PRGA_SAX_MSGTYPE_CREG_WRITE;
                            sax_data[`PRGA_SAX_CREG_STRB_INDEX] = strb_req_x;
                            sax_data[`PRGA_SAX_CREG_ADDR_INDEX] = addr_req_x;
                            sax_data[`PRGA_SAX_CREG_DATA_INDEX] = data_req_x;
                            stall_req_x = ~sax_rdy;
                        end
                        default: begin
                            prog_req_val_p = 1'b1;
                            prog_req_addr_p = addr_req_x;
                            prog_req_data_p = data_req_x;
                            prog_req_strb_p = strb_req_x;
                            stall_req_x = ~prog_req_rdy_f;
                        end
                    endcase
                end else begin
                    case (addr_req_x)
                        `PRGA_CREG_ADDR_BITSTREAM_ID: begin
                            i_ctrldataq_wr = 1'b1;
                            i_ctrldataq_din = bitstream_id;
                            stall_req_x = i_ctrldataq_full;
                        end
                        `PRGA_CREG_ADDR_EFLAGS: begin
                            i_ctrldataq_wr = 1'b1;
                            i_ctrldataq_din = eflags;
                            stall_req_x = i_ctrldataq_full;
                        end
                        `PRGA_CREG_ADDR_ACLK_DIV: begin
                            i_ctrldataq_wr = 1'b1;
                            i_ctrldataq_din[0+:`PRGA_CLKDIV_WIDTH] = aclk_div;
                            stall_req_x = i_ctrldataq_full;
                        end
                        `PRGA_CREG_ADDR_PROG_STATUS: begin
                            i_ctrldataq_wr = 1'b1;
                            i_ctrldataq_din[0+:`PRGA_PROG_STATUS_WIDTH] = prog_status_f;
                            stall_req_x = i_ctrldataq_full;
                        end
                        `PRGA_CREG_ADDR_APP_FEATURES: begin
                            i_ctrldataq_wr = 1'b1;
                            i_ctrldataq_din = app_features;
                            stall_req_x = i_ctrldataq_full;
                        end
                        `PRGA_CREG_ADDR_APP_RST,
                        `PRGA_CREG_ADDR_TIMEOUT: begin
                            sax_val = 1'b1;
                            sax_data[`PRGA_SAX_MSGTYPE_INDEX] = `PRGA_SAX_MSGTYPE_CREG_READ;
                            sax_data[`PRGA_SAX_CREG_ADDR_INDEX] = addr_req_x;
                            stall_req_x = ~sax_rdy;
                        end
                        default: begin
                            prog_req_val_p = 1'b1;
                            prog_req_addr_p = addr_req_x;
                            stall_req_x = ~prog_req_rdy_f;
                        end
                    endcase
                end
            end else if (app_en_x) begin
                sax_val = 1'b1;
                stall_req_x = ~sax_rdy;

                if (|strb_req_x) begin
                    sax_data[`PRGA_SAX_MSGTYPE_INDEX] = `PRGA_SAX_MSGTYPE_CREG_WRITE;
                    sax_data[`PRGA_SAX_CREG_STRB_INDEX] = strb_req_x;
                    sax_data[`PRGA_SAX_CREG_ADDR_INDEX] = addr_req_x;
                    sax_data[`PRGA_SAX_CREG_DATA_INDEX] = data_req_x;
                end else begin
                    sax_data[`PRGA_SAX_MSGTYPE_INDEX] = `PRGA_SAX_MSGTYPE_CREG_READ;
                    sax_data[`PRGA_SAX_CREG_ADDR_INDEX] = addr_req_x;
                end
            end else begin
                stall_req_x = 1'b0;
            end
        end else begin
            stall_req_x = 1'b0;
        end
    end

    // ========================================================================
    // -- Response State Machine ----------------------------------------------
    // ========================================================================

    // == Main Logic ==
    always @* begin
        creg_resp_val = 1'b0;
        creg_resp_data = {`PRGA_CREG_DATA_WIDTH {1'b0} };
        prog_resp_rdy_p = 1'b0;
        asx_rdy = 1'b0;

        eflags_set = 1'b0;
        eflags_set_mask = {`PRGA_CREG_DATA_WIDTH {1'b0} };
        i_tokenq_rd = 1'b0;
        i_ctrldataq_rd = 1'b0;

        // Priority 1: ASX Error Messages
        if (asx_val) begin
            case (asx_data[`PRGA_ASX_MSGTYPE_INDEX])
                `PRGA_ASX_MSGTYPE_ERR: begin
                    eflags_set = 1'b1;
                    eflags_set_mask = eflags_set_mask | asx_data[0+:`PRGA_CREG_DATA_WIDTH];
                    asx_rdy = 1'b1;
                end
            endcase
        end

        // Priority 2: PROG Error Messages
        if (prog_resp_val_f && prog_resp_err_f) begin
            eflags_set = 1'b1;
            eflags_set_mask = eflags_set_mask | prog_resp_data_f;
            prog_resp_rdy_p = 1'b1;
        end

        // Priority 3: Response
        if (~i_tokenq_empty) begin
            case (i_tokenq_dout)
                CREG_TOKEN_CTRL_READ: begin
                    creg_resp_val = ~i_ctrldataq_empty;
                    creg_resp_data = i_ctrldataq_dout;

                    if (creg_resp_rdy && ~i_ctrldataq_empty) begin
                        i_tokenq_rd = 1'b1;
                        i_ctrldataq_rd = 1'b1;
                    end
                end
                CREG_TOKEN_CTRL_WRITE: begin
                    creg_resp_val = 1'b1;
                    i_tokenq_rd = creg_resp_rdy;
                end
                CREG_TOKEN_PROG_READ,
                CREG_TOKEN_PROG_WRITE: if (prog_resp_val_f && ~prog_resp_err_f) begin
                    creg_resp_val = 1'b1;
                    creg_resp_data = prog_resp_data_f;
                    i_tokenq_rd = creg_resp_rdy;
                    prog_resp_rdy_p = creg_resp_rdy;
                end
                CREG_TOKEN_SAX_READ: if (asx_val && asx_data[`PRGA_ASX_MSGTYPE_INDEX] == `PRGA_ASX_MSGTYPE_CREG_READ_ACK) begin
                    creg_resp_val = 1'b1;
                    creg_resp_data = asx_data[0+:`PRGA_CREG_DATA_WIDTH];
                    i_tokenq_rd = creg_resp_rdy;
                    asx_rdy = creg_resp_rdy;
                end
                CREG_TOKEN_SAX_WRITE: if (asx_val && asx_data[`PRGA_ASX_MSGTYPE_INDEX] == `PRGA_ASX_MSGTYPE_CREG_WRITE_ACK) begin
                    creg_resp_val = 1'b1;
                    i_tokenq_rd = creg_resp_rdy;
                    asx_rdy = creg_resp_rdy;
                end
            endcase
        end
    end

endmodule
