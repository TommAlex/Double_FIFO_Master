/*
    Модуль  ШИМ-пульсации светодиода.
    Адаптирован под частоту 56 МГц и активный низкий уровень (Active-Low).
*/
module pwm_pulse (
    input  logic clk,         // Входная  частота (56 МГц)
    input  logic pwm_enable,  // 1 - включить ШИМ, 0 - статичное состояние
    input  logic fix_state,   // Состояние светодиода при выключенном ШИМ (1 - горит, 0 - погашен)
    output logic led_out      // Выход на светодиод (Active-Low: 0 = горит)
);

    // Начальная инициализация регистров 
    logic [15:0] pwm_cnt    = '0; // Счетчик периода ШИМ (65536 тактов)
    logic [7:0]  duty_cycle = '0; // Текущая яркость (0 - выключен, 255 - максимум)
    logic [23:0] speed_cnt  = '0; // Счетчик скорости изменения яркости
    logic        pwm_dir    = 1'b0; // Направление: 0 - разгорается, 1 - затухает
    logic        led_reg    = 1'b0; // Внутренний регистр яркости (прямая логика)
    
    logic        final_led_high;    // Итоговый сигнал в прямой логике (1 = должен гореть)

    always_ff @(posedge clk) begin
        // Внутренние счетчики ШИМ работают непрерывно
        pwm_cnt   <= pwm_cnt + 1'b1;
        led_reg   <= (pwm_cnt[15:8] < duty_cycle);
        speed_cnt <= speed_cnt + 1'b1;

        // Плавное изменение яркости (каждые 2^17 тактов ≈ 2.9 мс)
        if (speed_cnt[16:0] == '0) begin
            if (!pwm_dir) begin
                if (duty_cycle == 8'd255) pwm_dir <= 1'b1;
                else duty_cycle <= duty_cycle + 1'b1;
            end else begin
                if (duty_cycle == 8'd0) pwm_dir <= 1'b0;
                else duty_cycle <= duty_cycle - 1'b1;
            end
        end
    end

    // МУЛЬТИПЛЕКСОР pwm_enable: 
    assign final_led_high = pwm_enable ? led_reg : fix_state;

    // Инверсия под светодиод
    assign led_out = ~final_led_high;

endmodule : pwm_pulse