// Automatically generated by PRGA's RTL generator
`timescale 1ns/1ps

/*
* Memory Protection Layer.
*/

`include "prga_system.vh"

`ifdef DEFAULT_NETTYPE_NONE
`default_nettype none
`endif

module prga_mprot (
    input wire                                  clk,
    input wire                                  rst_n,

    // == SAX -> MPROT =======================================================
    output reg                                  sax_rdy,
    input wire                                  sax_val,
    input wire [`PRGA_SAX_DATA_WIDTH-1:0]       sax_data,

    // == MPROT -> ASX =======================================================
    input wire                                  asx_rdy,
    output reg                                  asx_val,
    output reg [`PRGA_ASX_DATA_WIDTH-1:0]       asx_data,

    // == Control Signals ====================================================
    input wire                                  app_en,

    input wire [`PRGA_CREG_DATA_WIDTH-1:0]      app_features,
    input wire [`PRGA_PROT_TIMER_WIDTH-1:0]     timeout_limit,
    input wire                                  urst_n,

    // == Generic Cache-Coherent Memory Interface ============================
    output reg                                  ccm_req_rdy,
    input wire                                  ccm_req_val,
    input wire [`PRGA_CCM_REQTYPE_WIDTH-1:0]    ccm_req_type,
    input wire [`PRGA_CCM_ADDR_WIDTH-1:0]       ccm_req_addr,
    input wire [`PRGA_CCM_DATA_WIDTH-1:0]       ccm_req_data,
    input wire [`PRGA_CCM_SIZE_WIDTH-1:0]       ccm_req_size,
    input wire [`PRGA_ECC_WIDTH-1:0]            ccm_req_ecc,

    input wire                                  ccm_resp_rdy,
    output reg                                  ccm_resp_val,
    output reg [`PRGA_CCM_RESPTYPE_WIDTH-1:0]   ccm_resp_type,
    output reg [`PRGA_CCM_CACHETAG_INDEX]       ccm_resp_addr,  // only used for invalidations
    output reg [`PRGA_CCM_CACHELINE_WIDTH-1:0]  ccm_resp_data
    );

    // =======================================================================
    // -- Extract Related APP Features ---------------------------------------
    // =======================================================================
    wire ccm_en, ccm_nc_en, ccm_l1cache_en, ccm_atomic_en, ccm_mthread_en;

    assign ccm_en = app_features[`PRGA_APP_CCM_EN_INDEX];
    assign ccm_nc_en = app_features[`PRGA_APP_CCM_NC_EN_INDEX];
    assign ccm_l1cache_en = app_features[`PRGA_APP_CCM_L1CACHE_EN_INDEX];
    assign ccm_atomic_en = app_features[`PRGA_APP_CCM_ATOMIC_EN_INDEX];
    assign ccm_mthread_en = app_features[`PRGA_APP_CCM_MTHREAD_EN_INDEX];

    // =======================================================================
    // -- Forward Declarations -----------------------------------------------
    // =======================================================================

    // == ASX messages caused by SAX messages ==
    reg                                 sax2asx_val, sax2asx_stall;
    reg [`PRGA_ASX_DATA_WIDTH-1:0]      sax2asx_data;

    // == Feedback signals ==
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
    // -- Handling Requests --------------------------------------------------
    // =======================================================================

    wire ccm_intf_en;
    assign ccm_intf_en = rst_n && app_en && ccm_en && urst_n && ~error_reported;

    // == Register All Inputs ==
    reg                                 ccm_req_val_f, ccm_req_stall;
    reg [`PRGA_CCM_REQTYPE_WIDTH-1:0]   ccm_req_type_f;
    reg [`PRGA_CCM_ADDR_WIDTH-1:0]      ccm_req_addr_f;
    reg [`PRGA_CCM_DATA_WIDTH-1:0]      ccm_req_data_f;
    reg [`PRGA_CCM_SIZE_WIDTH-1:0]      ccm_req_size_f;
    reg [`PRGA_ECC_WIDTH-1:0]           ccm_req_ecc_f;

    always @(posedge clk) begin
        if (~ccm_intf_en) begin
            ccm_req_val_f   <= 1'b0;
            ccm_req_type_f  <= {`PRGA_CCM_REQTYPE_WIDTH{1'b0} };
            ccm_req_addr_f  <= {`PRGA_CCM_ADDR_WIDTH{1'b0} };
            ccm_req_data_f  <= {`PRGA_CCM_DATA_WIDTH{1'b0} };
            ccm_req_size_f  <= {`PRGA_CCM_SIZE_WIDTH{1'b0} };
            ccm_req_ecc_f   <= {`PRGA_ECC_WIDTH{1'b0} };
        end else if (ccm_req_rdy && ccm_req_val) begin
            ccm_req_val_f   <= 1'b1;
            ccm_req_type_f  <= ccm_req_type;
            ccm_req_addr_f  <= ccm_req_addr;
            ccm_req_data_f  <= ccm_req_data;
            ccm_req_size_f  <= ccm_req_size;
            ccm_req_ecc_f   <= ccm_req_ecc;
        end else if (~ccm_req_stall) begin
            ccm_req_val_f   <= 1'b0;
        end
    end

    always @* begin
        ccm_req_rdy = ccm_intf_en && (~ccm_req_val_f || ~ccm_req_stall);
    end

    // == ECC Checker ==
    wire                                ccm_req_ecc_fail;
    {{ module.instances.i_ecc_checker.model.name }} #(
        .DATA_WIDTH                     (`PRGA_CCM_REQTYPE_WIDTH + `PRGA_CCM_ADDR_WIDTH + `PRGA_CCM_DATA_WIDTH + `PRGA_CCM_SIZE_WIDTH)
    ) i_ecc_checker (
        .clk                            (clk)
        ,.rst_n                         (rst_n)
        ,.data                          ({ccm_req_type_f, ccm_req_addr_f, ccm_req_data_f, ccm_req_size_f})
        ,.ecc                           (ccm_req_ecc_f)
        ,.fail                          (ccm_req_ecc_fail)
        );

    // == Validate Request Size ==
    wire                                ccm_req_inval_size;
    assign ccm_req_inval_size = ~(ccm_req_size_f == `PRGA_CCM_SIZE_1B ||
                                ccm_req_size_f == `PRGA_CCM_SIZE_2B ||
                                ccm_req_size_f == `PRGA_CCM_SIZE_4B ||
                                ccm_req_size_f == `PRGA_CCM_SIZE_8B ||
                                ccm_req_size_f == `PRGA_CCM_SIZE_CACHELINE);

    // == Check and Send Messages ==
    localparam  ST_REQ_RST          = 2'h0,
                ST_REQ_ACTIVE       = 2'h1,
                ST_REQ_INACTIVE     = 2'h2;

    reg [1:0] req_state, req_state_next;

    always @(posedge clk) begin
        if (~rst_n) begin
            req_state <= ST_REQ_RST;
        end else begin
            req_state <= req_state_next;
        end
    end

    always @* begin
        req_state_next = req_state;
        ccm_req_stall = 1'b1;
        sax2asx_stall = 1'b1;
        asx_val = 1'b0;
        asx_data = {`PRGA_ASX_DATA_WIDTH {1'b0} };
        report_error = 1'b0;

        case (req_state)
            ST_REQ_RST: begin
                req_state_next = ST_REQ_INACTIVE;
            end
            ST_REQ_ACTIVE: begin
                if (sax2asx_val) begin
                    asx_val = 1'b1;
                    asx_data = sax2asx_data;

                    if (asx_rdy) begin
                        sax2asx_stall = 1'b0;

                        if (sax2asx_data[`PRGA_ASX_MSGTYPE_INDEX] == `PRGA_ASX_MSGTYPE_ERR) begin
                            report_error = 1'b1;
                            req_state_next = ST_REQ_INACTIVE;
                        end
                    end
                end
                
                if (~ccm_intf_en) begin
                    req_state_next = ST_REQ_INACTIVE;
                end else if (~sax2asx_val && ccm_req_val_f) begin
                    asx_val = 1'b1;
                    ccm_req_stall = ~asx_rdy;

                    if (ccm_req_ecc_fail) begin
                        asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_ERR;
                        asx_data[`PRGA_EFLAGS_CCM_ECC] = 1'b1;

                        if (asx_rdy) begin
                            report_error = 1'b1;
                            req_state_next = ST_REQ_INACTIVE;
                        end
                    end else if (ccm_req_inval_size) begin
                        asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_ERR;
                        asx_data[`PRGA_EFLAGS_CCM_INVAL_SIZE] = 1'b1;

                        if (asx_rdy) begin
                            report_error = 1'b1;
                            req_state_next = ST_REQ_INACTIVE;
                        end
                    end else begin
                        case (ccm_req_type_f)
                            `PRGA_CCM_REQTYPE_LOAD: begin
                                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_CCM_LOAD;
                                asx_data[`PRGA_ASX_SIZE_INDEX] = ccm_req_size_f;
                                asx_data[`PRGA_CCM_DATA_WIDTH+:`PRGA_CCM_ADDR_WIDTH] = ccm_req_addr_f;
                            end
                            `PRGA_CCM_REQTYPE_STORE: begin
                                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_CCM_STORE;
                                asx_data[`PRGA_ASX_SIZE_INDEX] = ccm_req_size_f;
                                asx_data[`PRGA_CCM_DATA_WIDTH+:`PRGA_CCM_ADDR_WIDTH] = ccm_req_addr_f;
                                asx_data[0 +: `PRGA_CCM_DATA_WIDTH] = ccm_req_data_f;
                            end
                            `PRGA_CCM_REQTYPE_LOAD_NC: if (~ccm_nc_en) begin
                                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_ERR;
                                asx_data[`PRGA_EFLAGS_CCM_ILLEGAL_NC_REQ] = 1'b1;

                                if (asx_rdy) begin
                                    report_error = 1'b1;
                                    req_state_next = ST_REQ_INACTIVE;
                                end
                            end else begin
                                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_CCM_LOAD_NC;
                                asx_data[`PRGA_ASX_SIZE_INDEX] = ccm_req_size_f;
                                asx_data[`PRGA_CCM_DATA_WIDTH+:`PRGA_CCM_ADDR_WIDTH] = ccm_req_addr_f;
                            end
                            `PRGA_CCM_REQTYPE_STORE_NC: if (~ccm_nc_en) begin
                                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_ERR;
                                asx_data[`PRGA_EFLAGS_CCM_ILLEGAL_NC_REQ] = 1'b1;

                                if (asx_rdy) begin
                                    report_error = 1'b1;
                                    req_state_next = ST_REQ_INACTIVE;
                                end
                            end else begin
                                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_CCM_STORE_NC;
                                asx_data[`PRGA_ASX_SIZE_INDEX] = ccm_req_size_f;
                                asx_data[`PRGA_CCM_DATA_WIDTH+:`PRGA_CCM_ADDR_WIDTH] = ccm_req_addr_f;
                                asx_data[0 +: `PRGA_CCM_DATA_WIDTH] = ccm_req_data_f;
                            end
                            default: begin
                                asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_ERR;
                                asx_data[`PRGA_EFLAGS_CCM_INVAL_REQ] = 1'b1;

                                if (asx_rdy) begin
                                    report_error = 1'b1;
                                    req_state_next = ST_REQ_INACTIVE;
                                end
                            end
                        endcase
                    end
                end
            end
            ST_REQ_INACTIVE: begin
                if (sax2asx_val) begin
                    asx_val = 1'b1;
                    asx_data = sax2asx_data;

                    if (asx_rdy) begin
                        sax2asx_stall = 1'b0;
                        report_error = asx_data[`PRGA_ASX_MSGTYPE_INDEX] == `PRGA_ASX_MSGTYPE_ERR;
                    end
                end

                if (ccm_intf_en && ~(sax2asx_val && asx_data[`PRGA_ASX_MSGTYPE_INDEX] == `PRGA_ASX_MSGTYPE_ERR)) begin
                    req_state_next = ST_REQ_ACTIVE;
                end
            end
        endcase
    end

    // =======================================================================
    // -- Handling Responses -------------------------------------------------
    // =======================================================================

    // == Register SAX Inputs ==
    reg sax_val_f, sax_stall;
    reg [`PRGA_SAX_DATA_WIDTH-1:0] sax_data_f;

    always @(posedge clk) begin
        if (~rst_n) begin
            sax_val_f <= 1'b0;
            sax_data_f <= {`PRGA_SAX_DATA_WIDTH {1'b0} };
        end else if (sax_val && sax_rdy) begin
            sax_val_f <= 1'b1;
            sax_data_f <= sax_data;
        end else if (~sax_stall) begin
            sax_val_f <= 1'b0;
        end
    end

    always @* begin
        sax_rdy = rst_n && (~sax_val_f || ~sax_stall);
    end

    // == Response Timer ==
    reg resp_timeout_f;
    reg [`PRGA_PROT_TIMER_WIDTH-1:0] resp_timer;

    always @(posedge clk) begin
        if (~ccm_intf_en) begin
            resp_timeout_f <= 1'b0;
            resp_timer <= {`PRGA_PROT_TIMER_WIDTH{1'b0} };
        end else if (~resp_timeout_f) begin
            if (ccm_resp_rdy) begin
                resp_timer <= {`PRGA_PROT_TIMER_WIDTH{1'b0} };
            end else if (ccm_resp_val) begin
                resp_timer <= resp_timer + 1;
                resp_timeout_f <= resp_timer >= timeout_limit;
            end
        end
    end

    // == Response State Machine ==
    localparam  ST_RESP_RST             = 2'h0,
                ST_RESP_ACTIVE          = 2'h1,
                ST_RESP_INACTIVE        = 2'h2;

    reg [1:0] resp_state, resp_state_next;

    always @(posedge clk) begin
        if (~rst_n) begin
            resp_state <= ST_RESP_RST;
        end else begin
            resp_state <= resp_state_next;
        end
    end

    always @* begin
        resp_state_next = resp_state;
        sax_stall = 1'b1;
        sax2asx_val = 1'b0;
        sax2asx_data = {`PRGA_ASX_DATA_WIDTH {1'b0} };

        ccm_resp_val = 1'b0;
        ccm_resp_type = {`PRGA_CCM_RESPTYPE_WIDTH {1'b0} };
        ccm_resp_addr = { (`PRGA_CCM_CACHETAG_HIGH - `PRGA_CCM_CACHETAG_LOW + 1) {1'b0} };
        ccm_resp_data = {`PRGA_CCM_CACHELINE_WIDTH {1'b0} };

        case (resp_state)
            ST_RESP_RST: begin
                resp_state_next = ST_RESP_ACTIVE;
            end
            ST_RESP_ACTIVE: if (~ccm_intf_en) begin
                resp_state_next = ST_RESP_INACTIVE;
            end 

            // response timeout!
            else if (resp_timeout_f) begin
                sax2asx_val = 1'b1;
                sax2asx_data[`PRGA_ASX_MSGTYPE_INDEX] = `PRGA_ASX_MSGTYPE_ERR;
                sax2asx_data[`PRGA_EFLAGS_CCM_TIMEOUT] = 1'b1;

                if (~sax2asx_stall) begin
                    resp_state_next = ST_RESP_INACTIVE;
                end
            end

            // SAX message
            else if (sax_val_f) begin
                case (sax_data_f[`PRGA_SAX_MSGTYPE_INDEX])
                    `PRGA_SAX_MSGTYPE_CCM_LOAD_ACK,
                    `PRGA_SAX_MSGTYPE_CCM_LOAD_NC_ACK: begin
                        ccm_resp_val = 1'b1;
                        ccm_resp_data = sax_data_f[0+:`PRGA_CCM_CACHELINE_WIDTH];
                        sax_stall = ~ccm_resp_rdy;

                        if (sax_data_f[`PRGA_SAX_MSGTYPE_INDEX] == `PRGA_SAX_MSGTYPE_CCM_LOAD_NC_ACK) begin
                            ccm_resp_type = `PRGA_CCM_RESPTYPE_LOAD_NC_ACK;
                        end else begin
                            ccm_resp_type = `PRGA_CCM_RESPTYPE_LOAD_ACK;
                        end
                    end
                    `PRGA_SAX_MSGTYPE_CCM_STORE_ACK,
                    `PRGA_SAX_MSGTYPE_CCM_STORE_NC_ACK: begin
                        ccm_resp_val = 1'b1;
                        sax_stall = ~ccm_resp_rdy;

                        if (sax_data_f[`PRGA_SAX_MSGTYPE_INDEX] == `PRGA_SAX_MSGTYPE_CCM_STORE_NC_ACK) begin
                            ccm_resp_type = `PRGA_CCM_RESPTYPE_STORE_NC_ACK;
                        end else begin
                            ccm_resp_type = `PRGA_CCM_RESPTYPE_STORE_ACK;
                        end
                    end
                endcase
            end
            ST_RESP_INACTIVE: if (ccm_intf_en) begin
                resp_state_next = ST_RESP_ACTIVE;
            end else begin
                // TODO: handle SAX messages (e.g. invalidation)
                sax_stall = 1'b0;
            end
        endcase
    end

endmodule
