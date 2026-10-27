/*
	Multi-Channel FIFO Buffer
	Created By: Hector Soto
	Email: hector.soto@ftdichip.com
*/

module DOUBLE_FIFO_Buffer
#(
	//Below is for testing.
	parameter CH_BUF_SIZE = 14'd8192, //How many bytes each channel can hold.
	parameter CH_BUF_FBIT = 13 //14'd8192 full bit = bit 13 (14th bit).
)
(
	input logic				CLK,				//FIFO Clock.
	input logic				RST_N,			//Reset signal.
	input logic				RXF_N,			//RXF_N signal.
	//Buffer Interface
	input logic [1:0]		Channel,			//Channel buffer needs to send or receive data on.
	input logic				Receive,			//Channel is receiving data.
	input logic [31:0]	InData,			//Data provided by FIFO controller.
	input logic [3:0]		InBE,				//BE provided by FIFO controller.
	output logic [31:0]	OutData,			//Data provided by buffer.
	output logic [3:0]	OutBE,			//Enabled bytes provided by buffer.
	output logic 			SpaceReady,		//Has space to receive data.
	output logic 			DataReady		//Has data to send.
);

genvar g_i;

wire [1:0] Offset; //Address offset.
wire [2:0] InBytes; //Number of bytes we're receiving on this clock cycle.
wire [12:0] BR_address[4];
wire BR_wren; //Write data.
wire [31:0] BR_q;

wire [7:0] BR_InData[4];
wire [7:0] BR_OutData[4];

BYTE_RAM BR0(
	.address(BR_address[0]),
	.inclock(CLK),
	.data(BR_InData[2'd0 - Offset]),
	.wren(BR_wren & InBE[2'd0 - Offset]),
	.q(BR_q[7:0])
);

BYTE_RAM BR1(
	.address(BR_address[1]),
	.inclock(CLK),
	.data(BR_InData[2'd1 - Offset]),
	.wren(BR_wren & InBE[2'd1 - Offset]),
	.q(BR_q[15:8])
);

BYTE_RAM BR2(
	.address(BR_address[2]),
	.inclock(CLK),
	.data(BR_InData[2'd2 - Offset]),
	.wren(BR_wren & InBE[2'd2 - Offset]),
	.q(BR_q[23:16])
);

BYTE_RAM BR3(
	.address(BR_address[3]),
	.inclock(CLK),
	.data(BR_InData[2'd3 - Offset]),
	.wren(BR_wren & InBE[2'd3 - Offset]),
	.q(BR_q[31:24])
);

wire [3:0] OutRegBE;

reg [12:0] ReadAddress[4][2]; //0 = Normal address. 1 = Address + 1.
reg [12:0] WriteAddress[4][2]; //Buffer address we write to.
logic Empty[4]; //Buffer is empty, end or don't start write transactions.
logic Full[4]; //Buffer is full, end or don't start read transactions.
reg [13:0] StoredBytes[4]; //How many stored bytes we have for each channel.
//^14 bits lets us contain 8191 + 1.
//14th bit being high means we're full.

always_ff @(posedge CLK or negedge RST_N) begin
	if(~RST_N) begin
		for(logic [2:0] i = 0; i < 4; i++) begin
			StoredBytes[i] <= 14'd0;
			ReadAddress[i][0] <= 13'h1000;
			ReadAddress[i][1] <= 13'h1004;
			WriteAddress[i][0] <= 13'h1000;
			WriteAddress[i][1] <= 13'h1004;
		end
	end else begin
		if(~RXF_N) begin
			if(Receive & SpaceReady) begin //Increment address to output next data.
				if((StoredBytes[Channel] + InBytes) > CH_BUF_SIZE) begin
					StoredBytes[Channel] <= CH_BUF_SIZE;
					WriteAddress[Channel][0] <= WriteAddress[Channel][0] + 13'(CH_BUF_SIZE - StoredBytes[Channel]);
					WriteAddress[Channel][1] <= WriteAddress[Channel][1] + 13'(CH_BUF_SIZE - StoredBytes[Channel]);
				end else begin
					StoredBytes[Channel] <= StoredBytes[Channel] + InBytes;
					WriteAddress[Channel][0] <= WriteAddress[Channel][0] + InBytes;
					WriteAddress[Channel][1] <= WriteAddress[Channel][1] + InBytes;
				end
			end
			else if(~Receive & DataReady) begin //We're sending data.
				if(StoredBytes[Channel] < 4) begin
					StoredBytes[Channel] <= 14'd0;
					ReadAddress[Channel][0] <= ReadAddress[Channel][0] + StoredBytes[Channel][10:0];
					ReadAddress[Channel][1] <= ReadAddress[Channel][1] + StoredBytes[Channel][10:0];
				end else begin
					StoredBytes[Channel] <= StoredBytes[Channel] - 14'd4;
					ReadAddress[Channel][0] <= ReadAddress[Channel][0] + 13'd4;
					ReadAddress[Channel][1] <= ReadAddress[Channel][1] + 13'd4;
				end
			end
		end
	end
end

always_comb begin
	case(InBE)
		4'b0001: begin
			InBytes = 3'd1;
		end
		4'b0011: begin
			InBytes = 3'd2;
		end
		4'b0111: begin
			InBytes = 3'd3;
		end
		4'b1111: begin
			InBytes = 3'd4;
		end
		default: begin
			InBytes = 3'd0;
		end
	endcase
end

always_comb begin
	Offset = Receive ? WriteAddress[Channel][0][1:0] : ReadAddress[Channel][0][1:0];
	
	BR_address[0] = {
		Channel,
		Receive ?	WriteAddress[Channel][Offset > 2'b00][12:2] :
							ReadAddress[Channel][Offset > 2'b00][12:2] + (~RXF_N ? 11'd1 : 11'd0)
	};
	BR_address[1] = {
		Channel,
		Receive ?	WriteAddress[Channel][Offset > 2'b01][12:2] :
							ReadAddress[Channel][Offset > 2'b01][12:2] + (~RXF_N ? 11'd1 : 11'd0)
	};
	BR_address[2] = {
		Channel,
		Receive ?	WriteAddress[Channel][Offset > 2'b10][12:2] :
							ReadAddress[Channel][Offset > 2'b10][12:2] + (~RXF_N ? 11'd1 : 11'd0)
	};
	BR_address[3] = {
		Channel,
		Receive ?	WriteAddress[Channel][0][12:2] :
							ReadAddress[Channel][0][12:2] + (~RXF_N ? 11'd1 : 11'd0)
	};
	
	if(StoredBytes[Channel] > 3) begin //Have BE dependent on StoredBytes.
		OutRegBE = 4'b1111;
	end else if (StoredBytes[Channel] > 2) begin
		OutRegBE = 4'b0111;
	end else if (StoredBytes[Channel] > 1) begin
		OutRegBE = 4'b0011;
	end else if (StoredBytes[Channel] > 0) begin
		OutRegBE = 4'b0001;
	end else begin
		OutRegBE = 4'b0000;
	end
	
end

assign BR_InData[0] = InData[7:0];
assign BR_InData[1] = InData[15:8];
assign BR_InData[2] = InData[23:16];
assign BR_InData[3] = InData[31:24];
assign BR_OutData[0] = BR_q[7:0];
assign BR_OutData[1] = BR_q[15:8];
assign BR_OutData[2] = BR_q[23:16];
assign BR_OutData[3] = BR_q[31:24];

assign BR_wren = ~RXF_N & Receive;

assign OutData = {BR_OutData[2'd3 + Offset],
						BR_OutData[2'd2 + Offset],
						BR_OutData[2'd1 + Offset],
						BR_OutData[2'd0 + Offset]};
assign OutBE = OutRegBE;
generate
	for(g_i = 0; g_i < 4; g_i++) begin : EMPTY_FULL_BLOCK
		assign Empty[g_i] = StoredBytes[g_i] == 0;
		assign Full[g_i] = StoredBytes[g_i][CH_BUF_FBIT]; //Full if last bit is high.
	end : EMPTY_FULL_BLOCK
endgenerate
assign DataReady = ~Empty[Channel];
assign SpaceReady = ~Full[Channel];

endmodule : DOUBLE_FIFO_Buffer