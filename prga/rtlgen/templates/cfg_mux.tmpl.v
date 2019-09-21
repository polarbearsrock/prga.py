// Automatically generated by PRGA's RTL generator
module {{ module.name }} (
    input wire [{{ module.width - 1 }}:0] i,
    output wire [0:0] o,
    input wire [{{ module.width_sel - 1 }}:0] cfg_d,
    input wire [0:0] cfg_e
    );

    always @* begin
        o = 1'b0;
        if (~cfg_e) begin
            case (cfg_d)    // synopsys infer_mux
                {%- for idx in range(module.width) %}
                {{ module.width_sel }}'d{{ idx }}: o = i[{{ idx }}];
                {%- endfor %}
            endcase
        end
    end

endmodule
