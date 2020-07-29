// Automatically generated by PRGA's RTL generator
`timescale 1ns/1ps

/*
* User Protection Layer.
*/

`include "prga_system.vh"

`ifdef DEFAULT_NETTYPE_NONE
    `default_nettype none
`endif

module prga_uprot (
    input wire                                  clk,
    input wire                                  rst_n,

    // == SAX -> UPROT =======================================================
    output reg                                  sax_rdy,
    input wire                                  sax_val,
    input wire [`PRGA_SAX_DATA_WIDTH-1:0]       sax_data,

    // == UPROT -> ASX =======================================================
    input wire                                  asx_rdy,
    output reg                                  asx_val,
    output reg [`PRGA_ASX_DATA_WIDTH-1:0]       asx_data,

    // == Control Signals ====================================================
    input wire                                  app_en,         // is the APP enabled?

    output reg [`PRGA_CREG_DATA_WIDTH-1:0]      app_features,   // CDC sync'ed feature enabling flags
    output reg [`PRGA_PROT_TIMER_WIDTH-1:0]     timeout_limit,
    output reg                                  urst_n,

    // == Generic UREG Interface ==============================================
    input wire                                  ureg_req_rdy,
    output reg                                  ureg_req_val,
    output reg [`PRGA_CREG_ADDR_WIDTH-1:0]      ureg_req_addr,
    output reg [`PRGA_CREG_DATA_BYTES-1:0]      ureg_req_strb,
    output reg [`PRGA_CREG_DATA_WIDTH-1:0]      ureg_req_data,

    input wire                                  ureg_resp_val,
    output reg                                  ureg_resp_rdy,
    input wire [`PRGA_CREG_DATA_WIDTH-1:0]      ureg_resp_data,
    input wire [`PRGA_ECC_WIDTH-1:0]            ureg_resp_ecc
    );

    // =======================================================================
    // -- Ctrl Registers -----------------------------------------------------
    // =======================================================================

    // == APP features ==
    reg                                 app_features_update;
    reg [`PRGA_CREG_DATA_WIDTH-1:0]     app_features_next;

    always @(posedge clk) begin
        if (~rst_n) begin
            app_features                <= {`PRGA_CREG_DATA_WIDTH {1'b0} };
        end else if (app_features_update) begin
            app_features                <= app_features_next;
        end
    end

    wire                                        ureg_en;
    wire [`PRGA_APP_UREG_DWIDTH_WIDTH-1:0]      app_dwidth;

    assign ureg_en = app_features[`PRGA_APP_UREG_EN_INDEX];
    assign app_dwidth = app_features[`PRGA_APP_UREG_DWIDTH_INDEX];

    // == APP Reset ==
    reg                                 urst_countdown_rst;
    reg [`PRGA_PROT_TIMER_WIDTH-1:0]    urst_countdown, urst_countdown_rstvalue_f, urst_countdown_rstvalue;

    always @(posedge clk) begin
        if (~rst_n) begin
            // system reset locks application in reset state until explicitly de-reset
            urst_n                      <= 1'b0;
            urst_countdown              <= 1'b0;
            urst_countdown_rstvalue_f   <= {`PRGA_PROT_TIMER_WIDTH {1'b0} };
        end else begin
            if (urst_countdown_rst) begin
                urst_countdown_rstvalue_f   <= urst_countdown_rstvalue;
            end

            if (urst_countdown_rst || ~app_en) begin
                urst_n                  <= 1'b0;
                urst_countdown          <= urst_countdown_rstvalue;
            end else if (urst_countdown > 0) begin
                urst_countdown          <= urst_countdown - 1;

                if (urst_countdown == 1) begin
                    urst_n              <= 1'b1;
                end
            end
        end
    end

    // == UReg/CCM Timeout ==
    reg [`PRGA_PROT_TIMER_WIDTH-1:0]    timeout_limit_next;

    always @(posedge clk) begin
        if (~rst_n) begin
            timeout_limit   <= {`PRGA_PROT_TIMER_WIDTH {1'b0} };
        end else begin
            timeout_limit   <= timeout_limit_next;
        end
    end

    // =======================================================================
    // -- Pipeline -----------------------------------------------------------
    // =======================================================================

    /*
    * 3 Stages:
    *   
    *   Q (reQuest):    Send UREG request or execute CREG access
    *   R (Response):   Collect UREG response or pass CREG access to next stage
    *   X (ASX):        Send ASX response/error
    */

    reg stall_q, stall_r, stall_x;

    localparam  OP_WIDTH              = 3;
    localparam  OP_INVAL              = 3'h0,
                OP_READ_CREG          = 3'h1,
                OP_WRITE_CREG         = 3'h2,
                OP_READ_UREG          = 3'h3,
                OP_WRITE_UREG         = 3'h4,
                OP_READ_UREG_TIMEOUT  = 3'h5,
                OP_WRITE_UREG_TIMEOUT = 3'h6;

    // -- Q stage variables --
    reg                                 val_q;
    reg [`PRGA_SAX_DATA_WIDTH-1:0]      data_q;
    reg [OP_WIDTH-1:0]                  op_r_next;
    reg [`PRGA_CREG_DATA_WIDTH-1:0]     data_r_next;

    // -- R stage variables --
    reg [OP_WIDTH-1:0]                  op_r;
    reg [OP_WIDTH-1:0]                  op_x_next;
    reg [`PRGA_ECC_WIDTH-1:0]           ecc_x_next;
    reg [`PRGA_CREG_DATA_WIDTH-1:0]     data_r, data_x_next;

    // -- X stage variables --
    reg [OP_WIDTH-1:0]                  op_x;
    reg [`PRGA_ECC_WIDTH-1:0]           ecc_x;
    reg [`PRGA_CREG_DATA_WIDTH-1:0]     data_x;

    // -- Feedback signals --
    // error_reported is a fast path of ~app_en
    reg error_reported, report_error;

    always @(posedge clk) begin
        if (~(rst_n && app_en)) begin
            error_reported <= 1'b0;
        end else if (report_error) begin
            error_reported <= 1'b1;
        end
    end

    // =======================================================================
    // -- Q Stage ------------------------------------------------------------
    // =======================================================================

    // == Register Inputs ==
    always @(posedge clk) begin
        if (~rst_n) begin
            val_q   <= 1'b0;
            data_q  <= {`PRGA_SAX_DATA_WIDTH {1'b0} };
        end else if (sax_rdy && sax_val) begin
            val_q   <= 1'b1;
            data_q  <= sax_data;
        end else if (~stall_q) begin
            val_q   <= 1'b0;
        end
    end

    always @* begin
        sax_rdy = rst_n && (~val_q || ~stall_q);
    end

    // == UREG Request Timer ==
    reg req_timeout_f;
    reg [`PRGA_PROT_TIMER_WIDTH-1:0] req_timer;

    always @(posedge clk) begin
        if (~(rst_n && app_en)) begin
            req_timeout_f <= 1'b0;
            req_timer <= {`PRGA_PROT_TIMER_WIDTH {1'b0} };
        end else if (~req_timeout_f) begin
            if (ureg_req_rdy) begin
                req_timer <= {`PRGA_PROT_TIMER_WIDTH {1'b0} };
            end else if (ureg_req_val) begin
                req_timer <= req_timer + 1;
                req_timeout_f <= req_timer >= timeout_limit;
            end
        end
    end

    // == Main Logic ==
    always @* begin
        stall_q = stall_r;
        op_r_next = OP_INVAL;
        data_r_next = {`PRGA_CREG_DATA_WIDTH {1'b0} };

        ureg_req_val = 1'b0;
        ureg_req_addr = {`PRGA_CREG_ADDR_WIDTH {1'b0} };
        ureg_req_strb = {`PRGA_CREG_DATA_BYTES {1'b0} };
        ureg_req_data = {`PRGA_CREG_DATA_WIDTH {1'b0} };

        app_features_update = 1'b0;
        app_features_next = app_features;
        urst_countdown_rst = 1'b0;
        urst_countdown_rstvalue = urst_countdown_rstvalue_f;
        timeout_limit_next = timeout_limit;

        if (val_q && ~stall_r) begin
            case (data_q[`PRGA_SAX_MSGTYPE_INDEX])
                `PRGA_SAX_MSGTYPE_CREG_READ: if (data_q[`PRGA_SAX_CREG_ADDR_HIGH]) begin
                    // CREG read
                    op_r_next = OP_READ_CREG;

                    case (data_q[`PRGA_SAX_CREG_ADDR_INDEX])
                        `PRGA_CREG_ADDR_TIMEOUT: begin
                            data_r_next[0+:`PRGA_PROT_TIMER_WIDTH] = timeout_limit;
                        end
                    endcase
                end

                // == UREG read ==
                // ignore UREG read if app is not active, or a timeout/error has been reported
                else if (~(app_en && ureg_en && ~error_reported)) begin
                    op_r_next = OP_READ_CREG;
                end

                // request timeout
                else if (req_timeout_f) begin
                    op_r_next = OP_READ_UREG_TIMEOUT;
                end

                // wait if app is being reset
                else if (~urst_n) begin
                    stall_q = 1'b1;
                end

                // Send UREG request
                else begin
                    ureg_req_val = 1'b1;
                    ureg_req_addr = data_q[`PRGA_SAX_CREG_ADDR_INDEX];
                    ureg_req_strb = {`PRGA_CREG_DATA_BYTES {1'b0} };

                    if (ureg_req_rdy) begin
                        stall_q = 1'b0;
                        op_r_next = OP_READ_UREG;
                    end else begin
                        stall_q = 1'b1;
                    end
                end
                `PRGA_SAX_MSGTYPE_CREG_WRITE: if (data_q[`PRGA_SAX_CREG_ADDR_HIGH]) begin
                    // CREG write
                    op_r_next = OP_WRITE_CREG;

                    case (data_q[`PRGA_SAX_CREG_ADDR_INDEX])
                        `PRGA_CREG_ADDR_APP_FEATURES: begin
                            app_features_update = 1'b1;
                            app_features_next = data_q[0+:`PRGA_CREG_DATA_WIDTH];
                        end
                        `PRGA_CREG_ADDR_APP_RST: begin
                            urst_countdown_rst = 1'b1;
                            urst_countdown_rstvalue = data_q[0+:`PRGA_PROT_TIMER_WIDTH];
                        end
                        `PRGA_CREG_ADDR_TIMEOUT: begin
                            timeout_limit_next = data_q[0+:`PRGA_PROT_TIMER_WIDTH];
                        end
                    endcase
                end
                
                // == UREG write ==
                // ignore UREG write if app is not active, or a timeout/error has been reported
                else if (~(app_en && ureg_en && ~error_reported)) begin
                    op_r_next = OP_WRITE_CREG;
                end 

                // request timeout
                else if (req_timeout_f) begin
                    op_r_next = OP_WRITE_UREG_TIMEOUT;
                end

                // wait if app is being reset
                else if (~urst_n) begin
                    stall_q = 1'b1;
                end

                // Send UREG requst
                else begin
                    ureg_req_val = 1'b1;
                    ureg_req_addr = data_q[`PRGA_SAX_CREG_ADDR_INDEX];
                    ureg_req_data = data_q[0+:`PRGA_CREG_DATA_WIDTH];

                    case (app_dwidth)
                        `PRGA_APP_UREG_DWIDTH_1B: begin
                            ureg_req_strb = 8'h01 & data_q[`PRGA_SAX_CREG_STRB_INDEX];
                        end
                        `PRGA_APP_UREG_DWIDTH_2B: begin
                            ureg_req_strb = 8'h03 & data_q[`PRGA_SAX_CREG_STRB_INDEX];
                        end
                        `PRGA_APP_UREG_DWIDTH_4B: begin
                            ureg_req_strb = 8'h0f & data_q[`PRGA_SAX_CREG_STRB_INDEX];
                        end
                        default: begin
                            ureg_req_strb =         data_q[`PRGA_SAX_CREG_STRB_INDEX];
                        end
                    endcase

                    if (ureg_req_rdy) begin
                        stall_q = 1'b0;
                        op_r_next = OP_WRITE_UREG;
                    end else begin
                        stall_q = 1'b1;
                    end
                end
            endcase
        end
    end

    // =======================================================================
    // -- R Stage ------------------------------------------------------------
    // =======================================================================

    // == UREG Response Timer ==
    reg resp_timeout_f;
    reg [`PRGA_PROT_TIMER_WIDTH-1:0] resp_timer;

    always @(posedge clk) begin
        if (~(rst_n && app_en)) begin
            resp_timeout_f <= 1'b0;
            resp_timer <= {`PRGA_PROT_TIMER_WIDTH {1'b0} };
        end else if (~resp_timeout_f) begin
            if (ureg_resp_val) begin
                resp_timer <= {`PRGA_PROT_TIMER_WIDTH {1'b0} };
            end else if (ureg_resp_rdy) begin
                resp_timer <= resp_timer + 1;
                resp_timeout_f <= resp_timer >= timeout_limit;
            end
        end
    end

    // == Register signals from Q stage ==
    always @(posedge clk) begin
        if (~rst_n) begin
            op_r    <= OP_INVAL;
            data_r  <= {`PRGA_CREG_DATA_WIDTH {1'b0} };
        end else if (~stall_r) begin
            op_r    <= op_r_next;
            data_r  <= data_r_next;
        end
    end

    // == Main Logic ==
    always @* begin
        stall_r = stall_x;
        op_x_next = OP_INVAL;
        data_x_next = {`PRGA_CREG_DATA_WIDTH {1'b0} };
        ecc_x_next = {`PRGA_ECC_WIDTH {1'b0} };

        ureg_resp_rdy = 1'b0;

        if (~stall_x) begin
            case (op_r)
                OP_READ_CREG: begin
                    op_x_next = OP_READ_CREG;
                    data_x_next = data_r;
                end
                OP_WRITE_CREG: begin
                    op_x_next = OP_WRITE_CREG;
                end
                OP_READ_UREG: begin
                    // ignore UREG read if app is not active, or a timeout/error has
                    // been reported, or the app is being reset
                    if (~(urst_n && app_en && ureg_en && ~error_reported)) begin
                        op_x_next = OP_READ_CREG;
                    end

                    // response timeout
                    else if (resp_timeout_f) begin
                        op_x_next = OP_READ_UREG_TIMEOUT;
                    end

                    // Collect UREG response
                    else begin
                        ureg_resp_rdy = 1'b1;

                        if (ureg_resp_val) begin
                            op_x_next = OP_READ_UREG;
                            ecc_x_next = ureg_resp_ecc;
                            data_x_next = ureg_resp_data;
                        end else begin
                            stall_r = 1'b1;
                        end
                    end
                end
                OP_WRITE_UREG: begin
                    // ignore UREG write if app is not active, or a timeout/error has
                    // been reported, or the app is being reset
                    if (~(urst_n && app_en && ureg_en && ~error_reported)) begin
                        op_x_next = OP_WRITE_CREG;
                    end

                    // response timeout
                    else if (resp_timeout_f) begin
                        op_x_next = OP_WRITE_UREG_TIMEOUT;
                    end

                    // Collect UREG response
                    else begin
                        ureg_resp_rdy = 1'b1;

                        if (ureg_resp_val) begin
                            op_x_next = OP_WRITE_UREG;
                        end else begin
                            stall_r = 1'b1;
                        end
                    end
                end
                OP_READ_UREG_TIMEOUT: begin
                    op_x_next = OP_READ_UREG_TIMEOUT;
                end
                OP_WRITE_UREG_TIMEOUT: begin
                    op_x_next = OP_WRITE_UREG_TIMEOUT;
                end
            endcase
        end
    end

    // =======================================================================
    // -- X Stage ------------------------------------------------------------
    // =======================================================================

    // == Register signals from R stage ==
    always @(posedge clk) begin
        if (~rst_n) begin
            op_x    <= OP_INVAL;
            ecc_x   <= {`PRGA_ECC_WIDTH {1'b0} };
            data_x  <= {`PRGA_CREG_DATA_WIDTH {1'b0} };
        end else if (~stall_x) begin
            op_x    <= op_x_next;
            ecc_x   <= ecc_x_next;
            data_x  <= data_x_next;
        end
    end

    // == ECC Checker ==
    wire                                ureg_ecc_fail;

    {{ module.instances.i_ecc_checker.model.name }} #(
        .DATA_WIDTH                     (`PRGA_CREG_DATA_WIDTH)
    ) i_ecc_checker (
        .clk                            (clk)
        ,.rst_n                         (rst_n)
        ,.data                          (
            app_dwidth == `PRGA_APP_UREG_DWIDTH_1B ? {56'b0, data_x[0+:8]} :
            app_dwidth == `PRGA_APP_UREG_DWIDTH_2B ? {48'b0, data_x[0+:16]} :
            app_dwidth == `PRGA_APP_UREG_DWIDTH_4B ? {32'b0, data_x[0+:32]} :
                                                data_x
        )
        ,.ecc                           (ecc_x)
        ,.fail                          (ureg_ecc_fail)
        );

    // == Main Logic ==
    always @* begin
        stall_x = 1'b0;
        asx_val = 1'b0;
        asx_data = {`PRGA_ASX_DATA_WIDTH {1'b0} };
        report_error = 1'b0;

        case (op_x)
            OP_READ_CREG: begin
                asx_val = 1'b1;
                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_CREG_READ_ACK;
                asx_data[0+:`PRGA_CREG_DATA_WIDTH] = data_x;
                stall_x = ~asx_rdy;
            end
            OP_WRITE_CREG: begin
                asx_val = 1'b1;
                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_CREG_WRITE_ACK;
                stall_x = ~asx_rdy;
            end
            OP_READ_UREG: if (~(app_en && ureg_en && ~error_reported)) begin
                asx_val = 1'b1;
                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_CREG_READ_ACK;
                stall_x = ~asx_rdy;
            end else if (ureg_ecc_fail) begin
                asx_val = 1'b1;
                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_ERR;
                asx_data[`PRGA_EFLAGS_UREG_ECC] = 1'b1;
                stall_x = 1'b1;
                report_error = asx_rdy;
            end else begin
                asx_val = 1'b1;
                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_CREG_READ_ACK;

                case (app_dwidth)
                    `PRGA_APP_UREG_DWIDTH_1B: begin
                        asx_data[0+:`PRGA_CREG_DATA_WIDTH] = {8 {data_x[0+: 8]} };
                    end
                    `PRGA_APP_UREG_DWIDTH_2B: begin
                        asx_data[0+:`PRGA_CREG_DATA_WIDTH] = {4 {data_x[0+:16]} };
                    end
                    `PRGA_APP_UREG_DWIDTH_4B: begin
                        asx_data[0+:`PRGA_CREG_DATA_WIDTH] = {2 {data_x[0+:32]} };
                    end
                    default: begin
                        asx_data[0+:`PRGA_CREG_DATA_WIDTH] = data_x;
                    end
                endcase
                stall_x = ~asx_rdy;
            end
            OP_WRITE_UREG: begin
                asx_val = 1'b1;
                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_CREG_WRITE_ACK;
                stall_x = ~asx_rdy;
            end
            OP_READ_UREG_TIMEOUT: if (~(app_en && ureg_en && ~error_reported)) begin
                asx_val = 1'b1;
                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_CREG_READ_ACK;
                stall_x = ~asx_rdy;
            end else begin
                asx_val = 1'b1;
                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_ERR;
                asx_data[`PRGA_EFLAGS_UREG_TIMEOUT] = 1'b1;
                stall_x = 1'b1;
                report_error = asx_rdy;
            end
            OP_WRITE_UREG_TIMEOUT: if (~(app_en && ureg_en && ~error_reported)) begin
                asx_val = 1'b1;
                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_CREG_WRITE_ACK;
                stall_x = ~asx_rdy;
            end else begin
                asx_val = 1'b1;
                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_ERR;
                asx_data[`PRGA_EFLAGS_UREG_TIMEOUT] = 1'b1;
                stall_x = 1'b1;
                report_error = asx_rdy;
            end
        endcase
    end

endmodule
