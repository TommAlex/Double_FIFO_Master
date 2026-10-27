module reset_seq (
    input  logic        clk_56MHz,       // Частота тактирования 56 МГц
    input  logic        cmd_reset_req,   // Импульс запроса сброса по USB (Канал 3)
    
    output logic        ft601_reset_n,   // Физический сброс чипа FT601 (Active Low)
    output logic        rst_n_for_fsm    // Очищенный сброс для автомата ПЛИС
);

    localparam bit [20:0] START_VALUE       = 21'd1_056_000;
    localparam bit [20:0] CHIP_RELEASE_VAL  = 21'd56_000;

    // Аппаратная инициализация счетчика обратного отсчета при старте матрицы
    logic [20:0] rst_down_cnt = START_VALUE;
    logic        software_reset_active = 1'b0;
    logic [15:0] sw_rst_hold_cnt = '0;

    // 1. Логика фиксации программного сброса
    always_ff @(posedge clk_56MHz) begin
        if (cmd_reset_req) begin
            software_reset_active <= 1'b1;
            sw_rst_hold_cnt       <= '0;
        end else if (software_reset_active) begin
            if (sw_rst_hold_cnt < 16'd56000)
                sw_rst_hold_cnt <= sw_rst_hold_cnt + 1'b1;
            else
                software_reset_active <= 1'b0;
        end
    end

    // 2. Логика работы Countdown-таймера
    always_ff @(posedge clk_56MHz) begin
        if (software_reset_active) begin
            rst_down_cnt <= START_VALUE;
        end else begin
            if (rst_down_cnt > 21'd0) begin
                rst_down_cnt <= rst_down_cnt - 1'b1;
            end
        end
    end

    // 3. ИСПРАВЛЕНИЕ: Прямой комбинаторный вывод (Без триггеров!)
    // Это гарантирует, что уровни сигналов зависят ТОЛЬКО от реального значения счетчика
    // и физически не могут залипнуть в нуле при старте.
    assign ft601_reset_n = (software_reset_active) ? 1'b0 : (rst_down_cnt <= CHIP_RELEASE_VAL);
    assign rst_n_for_fsm = (software_reset_active) ? 1'b0 : (rst_down_cnt == 21'd0);

endmodule : reset_seq
