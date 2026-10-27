/*
	Top-level Multi-Channel FIFO Master interface.
	Created By: Hector Soto
	Email: hector.soto@ftdichip.com
    modified for FCUSB: alex  ver: 1.1: 20261010a
*/
 
module DOUBLE_FIFO_Master(
	//Test Logic
	//input logic				CLK_125MHz, //Input CLK. Hopefully 125MHz.
	//PIN_U12 / PIN_V12 (LVDS)
	//output logic			LED0_CLK_OUT //TEST LED.
	//PIN_L7 (2.5V)
    // alex 20261009 FCUSB interface
	input logic				clk_56MHz,  //FCUSB 56MHz clock.
	input logic				clk_106MHz, //FCUSB 106MHz clock.
	output logic [3:0]		LED,        //FCUSB LEDs.
    //original 
//	input logic				RST_N,      //Active low Reset. //alex 20261009: Отсутствует на FCUSB.
	input logic				CLK_FIFO,   //FIFO clock from FT60X.
	input logic				RXF_N,      //Bus slave->master data receive acknowledge signal.
	inout	logic	[31:0]	DATA,		//Data bus lines.
	inout logic [3:0]		BE,		//Byte Enable. Command read/write signal.
	output logic			WR_N	    //Bus master->slave transaction request signal.

);

// alex 20261010 интерфейс PLL для CLK_FIFO 
logic clk_fifo_buffered; 
logic pll_locked;        
// alex 20261011 статус из контроллера 
logic [1:0] fsm_state; 
logic fifo_bus_receive; // alex 20261011 Сигнал направления от FSM: 1 = Чтение (в FPGA), 0 = Запись (из FPGA)

wire [31:0] DATA_Wire; //Wire for DATA.
(* keep = 1 *) wire [31:0] DATA_IN; //Wire fot input data.
wire [3:0] BE_Wire; //Wire for BE.
(* keep = 1 *) wire [3:0] BE_IN; //Wire for input BE.


// alex 20261010 Пропускаем CLK_FIFO через PLL с коэффициентом 1 к 1
fifo_pll fifo_pll_inst (
 //   .areset (pll_areset),        // Управляется частотомером freq_watchdog // убираем тесты -1 блокировка здесь?
    .inclk0 (CLK_FIFO),
    .c0     (clk_fifo_buffered), 
    .locked (pll_locked)
);
// alex 20261010a  --- MC FIFO Master Controller с выбором варианта генерации ---


    DOUBLE_FIFO_Controller FM_4C (
//        .CLK(clk_fifo_buffered),//20261022 попробуем не чистить
        .CLK(CLK_FIFO), 
//        .RST_N(1'b1), // alex 20261010 Без сброса. отсутствует на FCUSB. (так не работает.)
		.RST_N(pll_locked), // Сброс контроллера когда стабилизируется CLK_FIFO (после каждого выхода из сна в энергосберегающем режиме!)
        .RXF_N(RXF_N),
        .DATA_IN(DATA_IN),
        .DATA_OUT(DATA_Wire),
        .BE_IN(BE_IN),
        .BE_OUT(BE_Wire),
		.WR_N(WR_N),
        .BUS_RECEIVE(fifo_bus_receive), // alex 20261011 выход направления из FSM контроллера
		.DEBUG_STATE(fsm_state) //Статус
    );

assign DATA_IN = DATA;
assign DATA = DATA_Wire;
assign BE_IN = BE;
assign BE = BE_Wire;

//  Управление светодиодами (Active-Low)

// --- LED[1]: тестовый ШИМ (работает всегда от clk_56MHz) ---

pwm_pulse led1_pulse_inst (
    .clk        (clk_56MHz),
    .pwm_enable (1'b1),       // ШИМ активен всегда
    .fix_state  (1'b0),       // Не используется
    .led_out    (LED[1])
);

//  Делитель  для индикации
logic [21:0] led_scaler;
always_ff @(posedge clk_56MHz) begin
    led_scaler <= led_scaler + 1'b1;
end
wire blink_fast = led_scaler[21]; // Частота мигания  ~13 Гц

wire bus_active     = (!WR_N) && (fsm_state == 2'b11); // FSM в состоянии DAT
wire transfer_error = bus_active && (!pll_locked);     // Ошибка: флаг обмена, но PLL сорвался?

//assign LED[2] = ~( (pll_locked && !bus_active) || (bus_active && fifo_bus_receive && blink_clk) ); // Зеленый: Готов / Прием
//assign LED[3] = ~( transfer_error || (bus_active && !fifo_bus_receive && blink_clk) );             // Красный: Ошибка / Передача

wire led_pwm; // ШИМ-сигнал

pwm_pulse led_pwm_inst (
    .clk        (clk_56MHz),
    .pwm_enable (1'b1),		// ШИМ включен постоянно
    .fix_state  (1'b0),
    .led_out    (led_pwm)	// Выход ШИМ 
);

// Зеленый USB : трехрежимный селектор
always_comb begin
    if (!pll_locked) begin
        // Режим 1: Клок спит -> подключаем  ШИМ
        LED[2] = led_pwm; 
    end else if (bus_active && fifo_bus_receive) begin
        // Режим 2: ПРИЕМ данных -> быстрое мигание
        LED[2] = ~blink_fast; 
    end else begin
        // Режим 3: Клок активен, но шина в простое -> горит постоянно
        LED[2] = 1'b0; // 0 = горит в Active-Low
    end
end

assign LED[3] = ~( 
    transfer_error ||                               // Горит постоянно при ошибке PLL во время транзакции
    (bus_active && !fifo_bus_receive && blink_fast) // Передача данных -> Быстроe мигание
);

//assign LED[3] = (DATA_Wire && bus_active) ? ~blink_fast : ~transfer_error;


// ---  LED[0] : выключен ---
assign LED[0] = 1'b1;

endmodule : DOUBLE_FIFO_Master