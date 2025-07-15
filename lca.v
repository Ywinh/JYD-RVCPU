module lca #(width=32) (
    input  [width-1:0] op1,
    input  [width-1:0] op2,
    input  [width-1:0] cin,
    output [width-1:0] sum,
    output cout
);

wire [width>>2:0] c;
assign c[0] = cin;
assign cout = c[width>>2];

genvar i;
for( i=0; i<width>>2; i=i+1) begin
    lca_4bit u_lca_4bit (
        .op1( op1[i*4+3:i*4] ),
        .op2( op2[i*4+3:i*4] ),
        .cin( c[i] ),
        .sum( sum[i*4+3:i*4] ),
        .cout( c[i+1])
    );
end

endmodule
