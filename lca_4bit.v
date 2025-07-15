module lca_4bit #(width=4) (
    input  [width-1:0] op1,
    input  [width-1:0] op2,
    input  cin,
    output [width-1:0] sum,
    output cout
);

wire [width-1:0] g;
wire [width-1:0] p;
wire [width:0] c;

//gp generator
genvar i;
for( i=0; i<width; i=i+1) begin
    pg_gen u_pg_gen(
        .a( op1[i]),
        .b( op2[i]),
        .g( g[i]  ),
        .p( p[i]  )
    );
end

//carry generator
assign c[0] = cin;
assign c[1] = g[0] | ( cin & p[0] );
assign c[2] = g[1] | ( (g[0] | ( cin & p[0]) ) & p[1] );
assign c[3] = g[2] | ( (g[1] | ( (g[0] | (cin & p[0]) ) & p[1])) & p[2] );
assign c[4] = g[3] | ( (g[2] | ( (g[1] | ( (g[0] | (cin & p[0]) ) & p[1])) & p[2] )) & p[3]);
assign cout = c[width];

//below writing mode doesn't expand the carry chain
//genvar j;
//for( j=1; j<=width; j=j+1) begin
//    assign c[j] = g[j-1] | (c[j-1] & p[j-1]);
//end

//sum generator
genvar k;
for( k=0; k<width; k=k+1) begin
    assign sum[k] = p[k] ^ c[k];
end

endmodule
