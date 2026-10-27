module indicator (
    input  logic        clk_56MHz,     // Частота 56 МГц
    input  logic        rst_n,         // Глобальный сброс
    
    // Сигналы мониторинга от автомата FT601
    input  logic [3:0]  fsm_state,     
    input  logic        fsm_receive,   
    input  logic        ch0_tx_full,   
    
    // Выходы на физические светодиоды (ACTIVE LOW: 0 = Горит, 1 = Погашен)
    output logic        led_green,     // Зеленый (Прием -- мигает / Idle - пульсирует)
    output logic        led_red,       // Красный (Передача-- мигает/ Ошибка - горит)
    output logic        led_power      // Светодиод питания (Пульсирует всегда)
);

    // Константы состояний FSM Гектора Сото
    localparam IDL = 4'd0;
    localparam DAT = 4'd3;

    // Внутренние счетчики
    logic [22:0] timer_cnt;            // Таймер для ШИМ и мигания
    logic [7:0]  pwm_cnt;              // Счетчик периода ШИМ (0..255)
    
    // Регистры  ШИМ режима Idle (Зеленый)
    logic [7:0]  pwm_duty;             
    logic        pwm_dir;              

    // Регистры  ШИМ индикатора  Power (Всегда)
    logic [7:0]  pwr_pwm_duty;         
    logic        pwr_pwm_dir;          

    wire is_idle    = (fsm_state == IDL);
    wire is_receive = (fsm_state == DAT) && fsm_receive;
    wire is_transmit = (fsm_state == DAT) && !fsm_receive;
    
    // Логика детекта ошибки
    reg        error_reg;
    reg [22:0] watchdog_cnt;

    // Внутренние промежуточные сигналы (Active High)
    logic        int_green;
    logic        int_red;
    logic        int_power;

    always_ff @(posedge clk_56MHz or negedge rst_n) begin
        if (!rst_n) begin
            watchdog_cnt <= '0;
            error_reg    <= 1'b0;
        end else begin
            if (fsm_state == DAT) begin
                if (watchdog_cnt < 23'd8_400_000) 
                    watchdog_cnt <= watchdog_cnt + 1'b1;
                else
                    error_reg <= 1'b1; 
            end else begin
                watchdog_cnt <= '0;
                if (ch0_tx_full) 
                    error_reg <= 1'b1; 
                else if (is_idle)
                    error_reg <= 1'b0; 
            end
        end
    end

    // таймер
    always_ff @(posedge clk_56MHz or negedge rst_n) begin
        if (!rst_n) begin
            timer_cnt <= '0;
            pwm_cnt   <= '0;
        end else begin
            timer_cnt <= timer_cnt + 1'b1;
            pwm_cnt   <= pwm_cnt + 1'b1;
        end
    end

    // 1. Генератор ШИМ в состоянии   Idle (Зеленый)
    always_ff @(posedge clk_56MHz or negedge rst_n) begin
        if (!rst_n) begin
            pwm_duty <= '0;
            pwm_dir  <= 1'b1;
        end else begin
            if (timer_cnt[16:0] == '0) begin 
                if (pwm_dir) begin
                    if (pwm_duty == 8'd254) pwm_dir <= 1'b0;
                    else pwm_duty <= pwm_duty + 1'b1;
                end else begin
                    if (pwm_duty == 8'd1) pwm_dir <= 1'b1;
                    else pwm_duty <= pwm_duty - 1'b1;
                end
            end
        end
    end

    // Генератор ШИМ для светодиода Power (Всегда)
    always_ff @(posedge clk_56MHz or negedge rst_n) begin
        if (!rst_n) begin
            pwr_pwm_duty <= 8'd20; 
            pwr_pwm_dir  <= 1'b1;
        end else begin
            if (timer_cnt[17:0] == '0) begin 
                if (pwr_pwm_dir) begin
                    if (pwr_pwm_duty == 8'd254) pwr_pwm_dir <= 1'b0;
                    else pwr_pwm_duty <= pwr_pwm_duty + 1'b1;
                end else begin
                    if (pwr_pwm_duty == 8'd1) pwr_pwm_dir <= 1'b1;
                    else pwr_pwm_duty <= pwr_pwm_duty - 1'b1;
                end
            end
        end
    end

    // Назначение внутренних сигналов (Active High)
    always_comb begin
        int_green = 1'b0;
        int_red   = 1'b0;

        // Канал ПИТАНИЯ активен всегда
        int_power = (pwm_cnt < pwr_pwm_duty);

        if (error_reg) begin
            int_red   = 1'b1;
            int_green = 1'b0;
        end else if (is_receive) begin
            int_green = timer_cnt[19]; // Быстрое моргание зеленым
            int_red   = 1'b0;
        end else if (is_transmit) begin
            int_green = 1'b0;
            int_red   = timer_cnt[19]; // Быстрое моргание красным
        end else if (is_idle) begin
            int_green = (pwm_cnt < pwm_duty); // ШИМ зеленого
            int_red   = 1'b0;
        end
    end

    // =================================================================
    //Переход на  ACTIVE LOW (0 = ГОРИТ, 1 = ПОГАШЕН)
    // =================================================================
    assign led_green = ~int_green;
    assign led_red   = ~int_red;
    assign led_power = ~int_power;

endmodule : indicator