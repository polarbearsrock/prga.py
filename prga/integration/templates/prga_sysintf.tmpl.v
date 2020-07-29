// Automatically generated by PRGA's RTL generator
`timescale 1ns/1ps

/*
* System integration interface.
*/

`include "prga_system.vh"

module prga_sysintf (
    // == System Control Signals ==============================================
    input wire                                  clk,
    input wire                                  rst_n,

    // == Generic Register-based Interface ====================================
    output wire                                 reg_req_rdy,
    input wire                                  reg_req_val,
    input wire [`PRGA_CREG_ADDR_WIDTH-1:0]      reg_req_addr,
    input wire [`PRGA_CREG_DATA_BYTES-1:0]      reg_req_strb,
    input wire [`PRGA_CREG_DATA_WIDTH-1:0]      reg_req_data,

    input wire                                  reg_resp_rdy,
    output wire                                 reg_resp_val,
    output wire [`PRGA_CREG_DATA_WIDTH-1:0]     reg_resp_data,

    // == Generic Cache-coherent interface ===================================
    input wire                                  ccm_req_rdy,
    output wire                                 ccm_req_val,
    output wire [`PRGA_CCM_REQTYPE_WIDTH-1:0]   ccm_req_type,
    output wire [`PRGA_CCM_ADDR_WIDTH-1:0]      ccm_req_addr,
    output wire [`PRGA_CCM_DATA_WIDTH-1:0]      ccm_req_data,
    output wire [`PRGA_CCM_SIZE_WIDTH-1:0]      ccm_req_size,

    output wire                                 ccm_resp_rdy,
    input wire                                  ccm_resp_val,
    input wire [`PRGA_CCM_RESPTYPE_WIDTH-1:0]   ccm_resp_type,
    input wire [`PRGA_CCM_CACHETAG_INDEX]       ccm_resp_addr,  // only used for invalidations
    input wire [`PRGA_CCM_CACHELINE_WIDTH-1:0]  ccm_resp_data,

    // == CTRL <-> CFG ========================================================
    output wire                                 cfg_rst_n,
    input wire [`PRGA_CFG_STATUS_WIDTH-1:0]     cfg_status,

    input wire                                  cfg_req_rdy,
    output wire                                 cfg_req_val,
    output wire [`PRGA_CREG_ADDR_WIDTH-1:0]     cfg_req_addr,
    output wire [`PRGA_CREG_DATA_BYTES-1:0]     cfg_req_strb,
    output wire [`PRGA_CREG_DATA_WIDTH-1:0]     cfg_req_data,

    input wire                                  cfg_resp_val,
    output wire                                 cfg_resp_rdy,
    input wire                                  cfg_resp_err,
    input wire [`PRGA_CREG_DATA_WIDTH-1:0]      cfg_resp_data,

    // == Application Control Signals ========================================
    output wire                                 aclk,
    output wire                                 arst_n,

    // == Generic Register-based Interface ===================================
    output wire                                 urst_n,

    input wire                                  ureg_req_rdy,
    output wire                                 ureg_req_val,
    output wire [`PRGA_CREG_ADDR_WIDTH-1:0]     ureg_req_addr,
    output wire [`PRGA_CREG_DATA_BYTES-1:0]     ureg_req_strb,
    output wire [`PRGA_CREG_DATA_WIDTH-1:0]     ureg_req_data,

    output wire                                 ureg_resp_rdy,
    input wire                                  ureg_resp_val,
    input wire [`PRGA_CREG_DATA_WIDTH-1:0]      ureg_resp_data,
    input wire [`PRGA_ECC_WIDTH-1:0]            ureg_resp_ecc,

    // == Generic Cache-coherent interface ===================================
    output wire                                 uccm_req_rdy,
    input wire                                  uccm_req_val,
    input wire [`PRGA_CCM_REQTYPE_WIDTH-1:0]    uccm_req_type,
    input wire [`PRGA_CCM_ADDR_WIDTH-1:0]       uccm_req_addr,
    input wire [`PRGA_CCM_DATA_WIDTH-1:0]       uccm_req_data,
    input wire [`PRGA_CCM_SIZE_WIDTH-1:0]       uccm_req_size,
    input wire [`PRGA_ECC_WIDTH-1:0]            uccm_req_ecc,

    input wire                                  uccm_resp_rdy,
    output wire                                 uccm_resp_val,
    output wire [`PRGA_CCM_RESPTYPE_WIDTH-1:0]  uccm_resp_type,
    output wire [`PRGA_CCM_CACHETAG_INDEX]      uccm_resp_addr,  // only used for invalidations
    output wire [`PRGA_CCM_CACHELINE_WIDTH-1:0] uccm_resp_data
    );

    wire sax_ctrl_rdy, ctrl_sax_val, ctrl_asx_rdy, asx_ctrl_val;
    wire sax_transducer_rdy, transducer_sax_val, transducer_asx_rdy, asx_transducer_val;
    wire uprot_sax_rdy, sax_uprot_val, asx_uprot_rdy, uprot_asx_val;
    wire mprot_sax_rdy, sax_mprot_val, asx_mprot_rdy, mprot_asx_val;
    wire [`PRGA_SAX_DATA_WIDTH-1:0] ctrl_sax_data, transducer_sax_data, sax_uprot_data, sax_mprot_data;
    wire [`PRGA_ASX_DATA_WIDTH-1:0] asx_ctrl_data, asx_transducer_data, uprot_asx_data, mprot_asx_data;
    wire app_en, app_en_aclk;
    wire [`PRGA_CREG_DATA_WIDTH-1:0] app_features, app_features_aclk;
    wire [`PRGA_PROT_TIMER_WIDTH-1:0] timeout_limit;

    prga_ctrl i_ctrl (
        .clk                                    (clk)
        ,.rst_n                                 (rst_n)

        ,.creg_req_rdy                          (reg_req_rdy)
        ,.creg_req_val                          (reg_req_val)
        ,.creg_req_addr                         (reg_req_addr)
        ,.creg_req_strb                         (reg_req_strb)
        ,.creg_req_data                         (reg_req_data)
        ,.creg_resp_rdy                         (reg_resp_rdy)
        ,.creg_resp_val                         (reg_resp_val)
        ,.creg_resp_data                        (reg_resp_data)

        ,.aclk                                  (aclk)
        ,.arst_n                                (arst_n)
        ,.app_en                                (app_en)
        ,.app_en_aclk                           (app_en_aclk)
        ,.app_features                          (app_features)

        ,.cfg_rst_n		                        (cfg_rst_n)
        ,.cfg_status		                    (cfg_status)
        ,.cfg_req_rdy		                    (cfg_req_rdy)
        ,.cfg_req_val		                    (cfg_req_val)
        ,.cfg_req_addr		                    (cfg_req_addr)
        ,.cfg_req_strb		                    (cfg_req_strb)
        ,.cfg_req_data		                    (cfg_req_data)
        ,.cfg_resp_val		                    (cfg_resp_val)
        ,.cfg_resp_rdy		                    (cfg_resp_rdy)
        ,.cfg_resp_err		                    (cfg_resp_err)
        ,.cfg_resp_data		                    (cfg_resp_data)

        ,.sax_rdy                               (sax_ctrl_rdy)
        ,.sax_val                               (ctrl_sax_val)
        ,.sax_data                              (ctrl_sax_data)
        ,.asx_rdy                               (ctrl_asx_rdy)
        ,.asx_val                               (asx_ctrl_val)
        ,.asx_data                              (asx_ctrl_data)
        );

    prga_ccm_transducer i_transducer (
        .clk                                    (clk)
        ,.rst_n                                 (rst_n)

        ,.app_en                                (app_en)
        ,.app_features                          (app_features)

		,.ccm_req_rdy			                (ccm_req_rdy)
		,.ccm_req_val			                (ccm_req_val)
		,.ccm_req_type			                (ccm_req_type)
		,.ccm_req_addr			                (ccm_req_addr)
		,.ccm_req_data			                (ccm_req_data)
		,.ccm_req_size			                (ccm_req_size)

		,.ccm_resp_rdy			                (ccm_resp_rdy)
		,.ccm_resp_val			                (ccm_resp_val)
		,.ccm_resp_type			                (ccm_resp_type)
		,.ccm_resp_addr			                (ccm_resp_addr)
        ,.ccm_resp_data                         (ccm_resp_data)

        ,.sax_rdy		                        (sax_transducer_rdy)
        ,.sax_val		                        (transducer_sax_val)
        ,.sax_data		                        (transducer_sax_data)
        ,.asx_rdy		                        (transducer_asx_rdy)
        ,.asx_val		                        (asx_transducer_val)
        ,.asx_data		                        (asx_transducer_data)
        );

    prga_sax i_sax (
        .clk                                    (clk)
        ,.rst_n                                 (rst_n)

        ,.sax_ctrl_rdy		                    (sax_ctrl_rdy)
        ,.ctrl_sax_val		                    (ctrl_sax_val)
        ,.ctrl_sax_data		                    (ctrl_sax_data)
        ,.ctrl_asx_rdy		                    (ctrl_asx_rdy)
        ,.asx_ctrl_val		                    (asx_ctrl_val)
        ,.asx_ctrl_data		                    (asx_ctrl_data)

        ,.sax_transducer_rdy		            (sax_transducer_rdy)
        ,.transducer_sax_val		            (transducer_sax_val)
        ,.transducer_sax_data		            (transducer_sax_data)
        ,.transducer_asx_rdy		            (transducer_asx_rdy)
        ,.asx_transducer_val		            (asx_transducer_val)
        ,.asx_transducer_data		            (asx_transducer_data)

        ,.aclk                                  (aclk)
        ,.arst_n                                (arst_n)

        ,.asx_uprot_rdy		                    (asx_uprot_rdy)
        ,.uprot_asx_val		                    (uprot_asx_val)
        ,.uprot_asx_data		                (uprot_asx_data)
        ,.uprot_sax_rdy		                    (uprot_sax_rdy)
        ,.sax_uprot_val		                    (sax_uprot_val)
        ,.sax_uprot_data		                (sax_uprot_data)

        ,.asx_mprot_rdy		                    (asx_mprot_rdy)
        ,.mprot_asx_val		                    (mprot_asx_val)
        ,.mprot_asx_data		                (mprot_asx_data)
        ,.mprot_sax_rdy		                    (mprot_sax_rdy)
        ,.sax_mprot_val		                    (sax_mprot_val)
        ,.sax_mprot_data		                (sax_mprot_data)
        );

    prga_uprot i_uprot (
        .clk                                    (aclk)
        ,.rst_n                                 (arst_n)

        ,.sax_rdy                               (uprot_sax_rdy)
        ,.sax_val                               (sax_uprot_val)
        ,.sax_data                              (sax_uprot_data)
        ,.asx_rdy                               (asx_uprot_rdy)
        ,.asx_val                               (uprot_asx_val)
        ,.asx_data                              (uprot_asx_data)

        ,.app_en                                (app_en_aclk)
        ,.app_features                          (app_features_aclk)
        ,.timeout_limit                         (timeout_limit)
        ,.urst_n                                (urst_n)

        ,.ureg_req_rdy                          (ureg_req_rdy)
        ,.ureg_req_val                          (ureg_req_val)
        ,.ureg_req_addr                         (ureg_req_addr)
        ,.ureg_req_strb                         (ureg_req_strb)
        ,.ureg_req_data                         (ureg_req_data)
        ,.ureg_resp_rdy                         (ureg_resp_rdy)
        ,.ureg_resp_val                         (ureg_resp_val)
        ,.ureg_resp_data                        (ureg_resp_data)
        ,.ureg_resp_ecc                         (ureg_resp_ecc)
        );

    prga_mprot i_mprot (
        .clk                                    (aclk)
        ,.rst_n                                 (arst_n)

        ,.sax_rdy                               (mprot_sax_rdy)
        ,.sax_val                               (sax_mprot_val)
        ,.sax_data                              (sax_mprot_data)
        ,.asx_rdy                               (asx_mprot_rdy)
        ,.asx_val                               (mprot_asx_val)
        ,.asx_data                              (mprot_asx_data)

        ,.app_en                                (app_en_aclk)
        ,.app_features                          (app_features_aclk)
        ,.timeout_limit                         (timeout_limit)
        ,.urst_n                                (urst_n)

        ,.ccm_req_rdy		                    (uccm_req_rdy)
        ,.ccm_req_val		                    (uccm_req_val)
        ,.ccm_req_type		                    (uccm_req_type)
        ,.ccm_req_addr		                    (uccm_req_addr)
        ,.ccm_req_data		                    (uccm_req_data)
        ,.ccm_req_size		                    (uccm_req_size)
        ,.ccm_req_ecc		                    (uccm_req_ecc)

        ,.ccm_resp_rdy		                    (uccm_resp_rdy)
        ,.ccm_resp_val		                    (uccm_resp_val)
        ,.ccm_resp_type		                    (uccm_resp_type)
        ,.ccm_resp_addr		                    (uccm_resp_addr)
        ,.ccm_resp_data		                    (uccm_resp_data)
        );

endmodule
