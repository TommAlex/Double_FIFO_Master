/*
	Multi-Channel FIFO Controller.
	Created By: Hector Soto
	Email: hector.soto@ftdichip.com
*/

//FIFO transaction states.
typedef enum bit [3:0] {IDL, CMD, TR1, DAT, TR2} FIFO_C_State;

module DOUBLE_FIFO_Controller (
    //MC FIFO Interface.
	input logic				CLK,			//66/100 MHz FIFO Clock.
	input logic				RST_N,		//Reset.
	input logic				RXF_N,		//Bus slave->master data receive acknowledge signal.
	input	logic	[31:0]	DATA_IN,		//Data bus lines input.
	output logic [31:0]		DATA_OUT,	//Data bus lines output.
	input logic [3:0]		BE_IN,		//Byte enable input.
	output logic [3:0]		BE_OUT,		//Byte enable output.
	output logic			WR_N,		//Bus master->slave transaction request signal.
	output logic			BUS_RECEIVE,//направление
	output logic [1:0]		DEBUG_STATE //Статус

);

FIFO_C_State State; //Current state.
FIFO_C_State LastState; //Last state.

//Using a bunch of regs to reduce comb logic.
(* keep *) reg [7:0] Priority; //Round-Robin Priority one-hot bit. {OUT[3:0], IN[3:0]}
(* keep *) reg [1:0] Channel; //Channel register to track what channel we're doing a transaction for.
(* keep *) reg [7:0] ReadIn; //Last bit controls if we're reading in data.
logic Receive; //Last bit of ReadIn.
logic EPR; //Endpoint Ready signal.
logic IDR; //Internal Device Ready signal.

//Buffer inputs.
(* keep *) logic [2:0] ChannelOut; //Channel for the current transaction.
logic [1:0] BufferChannelOut; //Channel for buffer. 3, 2, 1, 0.
//Buffer outputs.
logic SpaceReady; //Has space to receive data.
logic DataReady; //Has data to send.
logic [31:0] OutDATA;
logic [3:0] OutBE;

DOUBLE_FIFO_Buffer MCFB(
	.CLK(CLK),
	.RST_N(RST_N),
	.RXF_N(RXF_N),
	.Channel(BufferChannelOut),
	.Receive(Receive),
	.InData(DATA_IN),
	.InBE(BE_IN),
	.OutData(OutDATA),
	.OutBE(OutBE),
	.SpaceReady(SpaceReady),
	.DataReady(DataReady)
);
// =========================================================================
always_ff @(posedge CLK or negedge RST_N) begin
	if(~RST_N) begin
		State <= IDL;
		LastState <= IDL;
		Priority <= 8'h01;
		Channel <= 2'b01; //Start checking channel 1.
		ReadIn <= 8'b00001111;
	end else begin
		case(State)
			IDL: begin //IDLE.
				//If endpoint is ready and prioritized, begin transaction.
				if(EPR && IDR) begin
					State <= CMD; //Move to command state.
				end else begin //Increment round-robin scheduler.
					Priority <= {Priority[6:0], Priority[7]};
					ReadIn <= {ReadIn[6:0], ReadIn[7]};
					Channel <= Channel + 2'd1; //Increment channel register.
					//Every two additions increments the channel by 1.
				end
			end
			CMD: begin //COMMAND.
				State <= TR1; //Move to TR1.
			end
			TR1: begin //1st turn around.
				if(Receive) begin
					if(LastState == TR1) begin
						State <= DAT;
					end else begin
						State <= TR1;
					end
				end else begin
					State <= DAT;
				end
			end
			DAT: begin //DATA.
				if(IDR) begin
					//If RXF_N is high.
					if(RXF_N & (LastState == DAT)) begin
						State <= Receive ? IDL : TR2;
					end
				end else begin
					//WR_N is high.
					State <= Receive ? TR2 : IDL; //Go to turn around 2.
				end
			end
			TR2: begin //2nd turn around.
				State <= IDL;
			end
		endcase
		LastState <= State;
	end
end

always_comb begin
	case(State)
		IDL: begin //IDLE
			DATA_OUT[31:0] = 32'hFFFFZZFF; //Leave DATA[15:8] floating for slave.
			BE_OUT[3:0] = 4'b1111; //Drive BE high when idle.
			WR_N = 1'b1; //No transaction request.
		end
		CMD: begin //COMMAND
			DATA_OUT[31:0] = {16'hFFFF, 8'hZZ, 5'h00, ChannelOut};
			BE_OUT[3:0] = {3'b000, ~Receive};
			WR_N = 1'b0; //Transaction ongoing.
		end
		TR1: begin //Bus turn around 1
			DATA_OUT[31:0] = Receive ? 32'hZZZZZZZZ : {16'hFFFF, 8'hZZ, 5'h00, ChannelOut};
			BE_OUT[3:0] = Receive ? 4'bzzzz : 4'b0001;
			WR_N = 1'b0; //Transaction ongoing.
		end
		DAT: begin //DATA
			DATA_OUT[31:0] = Receive ? 32'hZZZZZZZZ : OutDATA;
			BE_OUT[3:0] = Receive ? 4'bzzzz : OutBE;
			WR_N = ~(IDR); //WR_N is low while ready.
		end
		TR2: begin //Only explicitly on write transaction when RXF_N high before WR_N.
			DATA_OUT[31:0] = 32'hFFFFZZFF; //Leave DATA[15:8] floating for slave.
			BE_OUT[3:0] = Receive ? 4'bzzzz : 4'b1111; //Drive BE high when idle.
			WR_N = 1'b1; //No transaction request.
		end
	endcase
end

//True if the endpoint for the current channel is ready.
assign EPR = |(Priority & (~DATA_IN[15:8]));
//True if the internal device is ready to send/receive on the current channel.
assign IDR = Receive ? SpaceReady : DataReady;

//ChannelOut will always be 3-bit 4, 3, 2, or 1.
//4, 1, 2, 3
assign ChannelOut = {~(|Channel[1:0]), Channel[1:0]};
//BufferChannelOut will always be 2-bit 3, 2, 1, or 0.
//3, 0, 1, 2
assign BufferChannelOut = {Channel[1] ~^ Channel[0], ~Channel[0]};
assign Receive = ReadIn[7]; //Last bit tells us if we're reading in data.
assign BUS_RECEIVE = Receive; // Выводим наружу

assign DEBUG_STATE = State[1:0]; //test

endmodule : DOUBLE_FIFO_Controller

