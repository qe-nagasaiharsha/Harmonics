//+------------------------------------------------------------------+
//|                                              patterns_inputs.mqh |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

enum pattern_type_enum {X_A_B, X_A_B_C, X_A_B_C_D, X_A_B_C_D_E};
enum pattern_direction_enum {Bearish, Bullish, Both};
enum divergence_type_enum  {None_Divergence, Time_Divergence, Volume_Divergence, Time_Volume_Divergence};

// =================================================================================================================
//                                                    SET 1
// =================================================================================================================

input group "******************************************"
input group "************* Pattern 1 ******************"
input group "******************************************"

input group "===== Pattern Type ====="
input bool active_set_1 = true; //Active Set
input int bars_limit_1 = 0; //Limit past bars
input pattern_type_enum pattern_type_1 = X_A_B_C_D; // Pattern Shape type
input pattern_direction_enum pattern_direction_1 = Bearish; // Pattern Direction

input group "===== Length Properties ====="

input int b_min_1 = 20; //B Min length index from  X
input int b_max_1 = 100; //B Max length index from x

input double px_lenght_percentage_1 = 10; //PX line % relative to XB

input double min_a_to_c_btw_x_b_1 = 0; //Min AC length % relative to XB
input double max_a_to_c_btw_x_b_1 = 100; //Max AC length % relative to XB

input double min_b_to_d_btw_x_b_1 = 0; //Min BD length % relative to XB
input double max_b_to_d_btw_x_b_1 = 100; //Max BD length % relative to XB

input double min_c_to_e_btw_x_b_1 = 0; //Min CE length % relative to XB
input double max_c_to_e_btw_x_b_1 = 100; //Max CE length % relative to XB

input group "===== Retracement of Points Properties ====="

input double max_width_percentage_1 = 100; //Max A retrace % from X
input double min_width_percentage_1 = 0; //Min A retrace % from X

input double x_to_a_b_max_1 = 100; //Max B retrace % from XA
input double x_to_a_b_min_1 = -100; //Min B retrace % from XA

input double max_width_c_xa_1 = 1000; // Max C retrace % from XA
input double min_width_c_xa_1 = -1000; // Min C retrace % from XA

input double max_width_c_ab_1 = 200; // Max C retrace % from AB
input double min_width_c_ab_1 = -200; // Min C retrace % from AB

input double max_width_d_xa_1 = 200; // Max D retrace % from XA
input double min_width_d_xa_1 = -200; // Min D retrace % from XA

input double max_width_d_bc_1 = 200; // Max D retrace % from BC
input double min_width_d_bc_1 = -200; // Min D retrace % from BC

input double max_width_e_cd_1 = 200; // Max E retrace % from CD
input double min_width_e_cd_1 = -200; // Min E retrace % from CD

input double max_width_e_xa_1 = 1000; // Max E retrace % from XA
input double min_width_e_xa_1 = -1000; // Min E retrace % from XA

input group "===== Dynamic height Properties ====="

input int every_increasing_of_value_1 = 5; // Every candle count increase
input double width_increasing_percentage_x_to_b_1 = 0; //  Height increase % for XB
input double width_increasing_percentage_a_e_1 = 0; //  Max price buffer % from AC and BD and CE

input group "===== Phase 2 ====="

input double f_percentage_1 = 50; //F Points height %
input int fg_increasing_percentage_1 = 5; // FG line increment %

input double first_line_percentage_1 = 4; //First Line %
input double first_line_decrease_percentage_1 = 0.01; //First Line Decrease %
input double maxBelow_maxAbove_diff_percentage_1 = 40; //M N approximately difference %
input int mn_extension_bars_1 = 20; //MN Extension bars count
input double mn_buffer_percent_1 = 0; //MN buffer percent
input double mn_length_percent_1 = 0;// MN Min Length percent
input bool filter_candle_direction_1 = false; // Filter Candle Direction for MN Breakout
input bool filter_candle_engulf_close_1 = false; // Filter Candle Engulfing By Close for MN Breakout
input bool filter_candle_engulf_shadow_1 = false; // Filter Candle Engulfing By Shadow for MN Breakout
input bool extension_break_close_1 = false; // Extension Break By Close
input divergence_type_enum divergence_type_1 = None_Divergence;
input int tick_min_speed_1 = 500000; //TickChart min speed


// =================================================================================================================
//                                                    SET 2
// =================================================================================================================

input group "******************************************"
input group "************* Pattern 2 ******************"
input group "******************************************"

input group "===== Pattern Type ====="
input bool active_set_2 = false; //Active Set
input int bars_limit_2 = 0; //Limit past bars
input pattern_type_enum pattern_type_2 = X_A_B_C_D; // Pattern Shape type
input pattern_direction_enum pattern_direction_2 = Bearish; // Pattern Direction

input group "===== Length Properties ====="

input int b_min_2 = 20; //B Min length index from  X
input int b_max_2 = 100; //B Max length index from x

input double px_lenght_percentage_2 = 10; //PX line % relative to XB

input double min_a_to_c_btw_x_b_2 = 0; //Min AC length % relative to XB
input double max_a_to_c_btw_x_b_2 = 100; //Max AC length % relative to XB

input double min_b_to_d_btw_x_b_2 = 0; //Min BD length % relative to XB
input double max_b_to_d_btw_x_b_2 = 100; //Max BD length % relative to XB

input double min_c_to_e_btw_x_b_2 = 0; //Min CE length % relative to XB
input double max_c_to_e_btw_x_b_2 = 100; //Max CE length % relative to XB

input group "===== Retracement of Points Properties ====="

input double max_width_percentage_2 = 100; //Max A retrace % from X
input double min_width_percentage_2 = 0; //Min A retrace % from X

input double x_to_a_b_max_2 = 100; //Max B retrace % from XA
input double x_to_a_b_min_2 = -100; //Min B retrace % from XA

input double max_width_c_xa_2 = 1000; // Max C retrace % from XA
input double min_width_c_xa_2 = -1000; // Min C retrace % from XA

input double max_width_c_ab_2 = 200; // Max C retrace % from AB
input double min_width_c_ab_2 = -200; // Min C retrace % from AB

input double max_width_d_xa_2 = 200; // Max D retrace % from XA
input double min_width_d_xa_2 = -200; // Min D retrace % from XA

input double max_width_d_bc_2 = 200; // Max D retrace % from BC
input double min_width_d_bc_2 = -200; // Min D retrace % from BC

input double max_width_e_cd_2 = 200; // Max E retrace % from CD
input double min_width_e_cd_2 = -200; // Min E retrace % from CD

input double max_width_e_xa_2 = 1000; // Max E retrace % from XA
input double min_width_e_xa_2 = -1000; // Min E retrace % from XA

input group "===== Dynamic height Properties ====="

input int every_increasing_of_value_2 = 5; // Every candle count increase
input double width_increasing_percentage_x_to_b_2 = 0; //  Height increase % for XB
input double width_increasing_percentage_a_e_2 = 0; //  Max price buffer % from AC and BD and CE

input group "===== Phase 2 ====="

input double f_percentage_2 = 50; //F Points height %
input int fg_increasing_percentage_2 = 5; // FG line increment %

input double first_line_percentage_2 = 4; //First Line %
input double first_line_decrease_percentage_2 = 0.01; //First Line Decrease %
input double maxBelow_maxAbove_diff_percentage_2 = 40; //M N approximately difference %
input int mn_extension_bars_2 = 20; //MN Extension bars count
input double mn_buffer_percent_2 = 0; //MN buffer percent
input double mn_length_percent_2 = 0;// MN Min Length percent
input bool filter_candle_direction_2 = false; // Filter Candle Direction for MN Breakout
input bool filter_candle_engulf_close_2 = false; // Filter Candle Engulfing By Close for MN Breakout
input bool filter_candle_engulf_shadow_2 = false; // Filter Candle Engulfing By Shadow for MN Breakout
input bool extension_break_close_2 = false; // Extension Break By Close
input divergence_type_enum divergence_type_2 = None_Divergence;
input int tick_min_speed_2 = 500000; //TickChart min speed


// =================================================================================================================
//                                                    SET 3
// =================================================================================================================

input group "******************************************"
input group "************* Pattern 3 ******************"
input group "******************************************"

input group "===== Pattern Type ====="
input bool active_set_3 = false; //Active Set
input int bars_limit_3 = 0; //Limit past bars
input pattern_type_enum pattern_type_3 = X_A_B_C_D; // Pattern Shape type
input pattern_direction_enum pattern_direction_3 = Bearish; // Pattern Direction

input group "===== Length Properties ====="

input int b_min_3 = 20; //B Min length index from  X
input int b_max_3 = 100; //B Max length index from x

input double px_lenght_percentage_3 = 10; //PX line % relative to XB

input double min_a_to_c_btw_x_b_3 = 0; //Min AC length % relative to XB
input double max_a_to_c_btw_x_b_3 = 100; //Max AC length % relative to XB

input double min_b_to_d_btw_x_b_3 = 0; //Min BD length % relative to XB
input double max_b_to_d_btw_x_b_3 = 100; //Max BD length % relative to XB

input double min_c_to_e_btw_x_b_3 = 0; //Min CE length % relative to XB
input double max_c_to_e_btw_x_b_3 = 100; //Max CE length % relative to XB

input group "===== Retracement of Points Properties ====="

input double max_width_percentage_3 = 100; //Max A retrace % from X
input double min_width_percentage_3 = 0; //Min A retrace % from X

input double x_to_a_b_max_3 = 100; //Max B retrace % from XA
input double x_to_a_b_min_3 = -100; //Min B retrace % from XA

input double max_width_c_xa_3 = 1000; // Max C retrace % from XA
input double min_width_c_xa_3 = -1000; // Min C retrace % from XA

input double max_width_c_ab_3 = 200; // Max C retrace % from AB
input double min_width_c_ab_3 = -200; // Min C retrace % from AB

input double max_width_d_xa_3 = 200; // Max D retrace % from XA
input double min_width_d_xa_3 = -200; // Min D retrace % from XA

input double max_width_d_bc_3 = 200; // Max D retrace % from BC
input double min_width_d_bc_3 = -200; // Min D retrace % from BC

input double max_width_e_cd_3 = 200; // Max E retrace % from CD
input double min_width_e_cd_3 = -200; // Min E retrace % from CD

input double max_width_e_xa_3 = 1000; // Max E retrace % from XA
input double min_width_e_xa_3 = -1000; // Min E retrace % from XA

input group "===== Dynamic height Properties ====="

input int every_increasing_of_value_3 = 5; // Every candle count increase
input double width_increasing_percentage_x_to_b_3 = 0; //  Height increase % for XB
input double width_increasing_percentage_a_e_3 = 0; //  Max price buffer % from AC and BD and CE

input group "===== Phase 2 ====="

input double f_percentage_3 = 50; //F Points height %
input int fg_increasing_percentage_3 = 5; // FG line increment %

input double first_line_percentage_3 = 4; //First Line %
input double first_line_decrease_percentage_3 = 0.01; //First Line Decrease %
input double maxBelow_maxAbove_diff_percentage_3 = 40; //M N approximately difference %
input int mn_extension_bars_3 = 20; //MN Extension bars count
input double mn_buffer_percent_3 = 0; //MN buffer percent
input double mn_length_percent_3 = 0;// MN Min Length percent
input bool filter_candle_direction_3 = false; // Filter Candle Direction for MN Breakout
input bool filter_candle_engulf_close_3 = false; // Filter Candle Engulfing By Close for MN Breakout
input bool filter_candle_engulf_shadow_3 = false; // Filter Candle Engulfing By Shadow for MN Breakout
input bool extension_break_close_3 = false; // Extension Break By Close
input divergence_type_enum divergence_type_3 = None_Divergence;
input int tick_min_speed_3 = 500000; //TickChart min speed

// =================================================================================================================
//                                                    SET 4
// =================================================================================================================

input group "******************************************"
input group "************* Pattern 4 ******************"
input group "******************************************"

input group "===== Pattern Type ====="
input bool active_set_4 = false; //Active Set
input int bars_limit_4 = 0; //Limit past bars
input pattern_type_enum pattern_type_4 = X_A_B_C_D; // Pattern Shape type
input pattern_direction_enum pattern_direction_4 = Bearish; // Pattern Direction

input group "===== Length Properties ====="

input int b_min_4 = 20; //B Min length index from  X
input int b_max_4 = 100; //B Max length index from x

input double px_lenght_percentage_4 = 10; //PX line % relative to XB

input double min_a_to_c_btw_x_b_4 = 0; //Min AC length % relative to XB
input double max_a_to_c_btw_x_b_4 = 100; //Max AC length % relative to XB

input double min_b_to_d_btw_x_b_4 = 0; //Min BD length % relative to XB
input double max_b_to_d_btw_x_b_4 = 100; //Max BD length % relative to XB

input double min_c_to_e_btw_x_b_4 = 0; //Min CE length % relative to XB
input double max_c_to_e_btw_x_b_4 = 100; //Max CE length % relative to XB

input group "===== Retracement of Points Properties ====="

input double max_width_percentage_4 = 100; //Max A retrace % from X
input double min_width_percentage_4 = 0; //Min A retrace % from X

input double x_to_a_b_max_4 = 100; //Max B retrace % from XA
input double x_to_a_b_min_4 = -100; //Min B retrace % from XA

input double max_width_c_xa_4 = 1000; // Max C retrace % from XA
input double min_width_c_xa_4 = -1000; // Min C retrace % from XA

input double max_width_c_ab_4 = 200; // Max C retrace % from AB
input double min_width_c_ab_4 = -200; // Min C retrace % from AB

input double max_width_d_xa_4 = 200; // Max D retrace % from XA
input double min_width_d_xa_4 = -200; // Min D retrace % from XA

input double max_width_d_bc_4 = 200; // Max D retrace % from BC
input double min_width_d_bc_4 = -200; // Min D retrace % from BC

input double max_width_e_cd_4 = 200; // Max E retrace % from CD
input double min_width_e_cd_4 = -200; // Min E retrace % from CD

input double max_width_e_xa_4 = 1000; // Max E retrace % from XA
input double min_width_e_xa_4 = -1000; // Min E retrace % from XA

input group "===== Dynamic height Properties ====="

input int every_increasing_of_value_4 = 5; // Every candle count increase
input double width_increasing_percentage_x_to_b_4 = 0; //  Height increase % for XB
input double width_increasing_percentage_a_e_4 = 0; //  Max price buffer % from AC and BD and CE

input group "===== Phase 2 ====="

input double f_percentage_4 = 50; //F Points height %
input int fg_increasing_percentage_4 = 5; // FG line increment %

input double first_line_percentage_4 = 4; //First Line %
input double first_line_decrease_percentage_4 = 0.01; //First Line Decrease %
input double maxBelow_maxAbove_diff_percentage_4 = 40; //M N approximately difference %
input int mn_extension_bars_4 = 20; //MN Extension bars count
input double mn_buffer_percent_4 = 0; //MN buffer percent
input double mn_length_percent_4 = 0;// MN Min Length percent
input bool filter_candle_direction_4 = false; // Filter Candle Direction for MN Breakout
input bool filter_candle_engulf_close_4 = false; // Filter Candle Engulfing By Close for MN Breakout
input bool filter_candle_engulf_shadow_4 = false; // Filter Candle Engulfing By Shadow for MN Breakout
input bool extension_break_close_4 = false; // Extension Break By Close
input divergence_type_enum divergence_type_4 = None_Divergence;
input int tick_min_speed_4 = 500000; //TickChart min speed



// =================================================================================================================
//                                                    SET 5
// =================================================================================================================

input group "******************************************"
input group "************* Pattern 5 ******************"
input group "******************************************"

input group "===== Pattern Type ====="
input bool active_set_5 = false; //Active Set
input int bars_limit_5 = 0; //Limit past bars
input pattern_type_enum pattern_type_5 = X_A_B_C_D; // Pattern Shape type
input pattern_direction_enum pattern_direction_5 = Bearish; // Pattern Direction

input group "===== Length Properties ====="

input int b_min_5 = 20; //B Min length index from  X
input int b_max_5 = 100; //B Max length index from x

input double px_lenght_percentage_5 = 10; //PX line % relative to XB

input double min_a_to_c_btw_x_b_5 = 0; //Min AC length % relative to XB
input double max_a_to_c_btw_x_b_5 = 100; //Max AC length % relative to XB

input double min_b_to_d_btw_x_b_5 = 0; //Min BD length % relative to XB
input double max_b_to_d_btw_x_b_5 = 100; //Max BD length % relative to XB

input double min_c_to_e_btw_x_b_5 = 0; //Min CE length % relative to XB
input double max_c_to_e_btw_x_b_5 = 100; //Max CE length % relative to XB

input group "===== Retracement of Points Properties ====="

input double max_width_percentage_5 = 100; //Max A retrace % from X
input double min_width_percentage_5 = 0; //Min A retrace % from X

input double x_to_a_b_max_5 = 100; //Max B retrace % from XA
input double x_to_a_b_min_5 = -100; //Min B retrace % from XA

input double max_width_c_xa_5 = 1000; // Max C retrace % from XA
input double min_width_c_xa_5 = -1000; // Min C retrace % from XA

input double max_width_c_ab_5 = 200; // Max C retrace % from AB
input double min_width_c_ab_5 = -200; // Min C retrace % from AB

input double max_width_d_xa_5 = 200; // Max D retrace % from XA
input double min_width_d_xa_5 = -200; // Min D retrace % from XA

input double max_width_d_bc_5 = 200; // Max D retrace % from BC
input double min_width_d_bc_5 = -200; // Min D retrace % from BC

input double max_width_e_cd_5 = 200; // Max E retrace % from CD
input double min_width_e_cd_5 = -200; // Min E retrace % from CD

input double max_width_e_xa_5 = 1000; // Max E retrace % from XA
input double min_width_e_xa_5 = -1000; // Min E retrace % from XA

input group "===== Dynamic height Properties ====="

input int every_increasing_of_value_5 = 5; // Every candle count increase
input double width_increasing_percentage_x_to_b_5 = 0; //  Height increase % for XB
input double width_increasing_percentage_a_e_5 = 0; //  Max price buffer % from AC and BD and CE

input group "===== Phase 2 ====="

input double f_percentage_5 = 50; //F Points height %
input int fg_increasing_percentage_5 = 5; // FG line increment %

input double first_line_percentage_5 = 4; //First Line %
input double first_line_decrease_percentage_5 = 0.01; //First Line Decrease %
input double maxBelow_maxAbove_diff_percentage_5 = 40; //M N approximately difference %
input int mn_extension_bars_5 = 20; //MN Extension bars count
input double mn_buffer_percent_5 = 0; //MN buffer percent
input double mn_length_percent_5 = 0;// MN Min Length percent
input bool filter_candle_direction_5 = false; // Filter Candle Direction for MN Breakout
input bool filter_candle_engulf_close_5 = false; // Filter Candle Engulfing By Close for MN Breakout
input bool filter_candle_engulf_shadow_5 = false; // Filter Candle Engulfing By Shadow for MN Breakout
input bool extension_break_close_5 = false; // Extension Break By Close
input divergence_type_enum divergence_type_5 = None_Divergence;
input int tick_min_speed_5 = 500000; //TickChart min speed


// =================================================================================================================
//                                                  COMMONS SET
// =================================================================================================================


input group "===== Styles ====="
input color arrow_buy_color = clrViolet; // Buy Arrow Color
input color arrow_sell_color = clrRed; // Sell Arrow Color
input int arrow_size = 4; // Arrow Size

input bool draw_labels = true;//Show Label
input int label_font_size = 11;// Label Size
input color label_font_color = clrRed; // Label Color

input bool draw_lines = true; // Show Lines
input bool draw_mn = true; //Show MN Line
input bool draw_fg = false; //Show FG Line
input bool draw_slope = false; //Show Slope Line

input color px_color = clrRed; //PX Color
input color xa_color = clrOrange; //XA Color
input color ab_color = clrYellow; //AB Color
input color bc_color = clrLightBlue; //BC Color
input color cd_color = clrBlue; //CD Color
input color de_color = clrPurple; //DE Color
input color mn_color = clrWheat; //MN Color
input color fg_color = clrKhaki; //FG Color
input color slope_color = clrBlue; //Slope Color

input group "===== Debug ====="
input bool testing_mode = false;
input string start_test_time = "2021.01.00 [00:00]";
input string end_test_time = "2021.01.15 [00:00]";

input group "===== Trade Management ====="
enum entry_type_enum {FIXED, MARKET};
input entry_type_enum entry_type = FIXED;
input double stoploss_percent = 0.2; //Stop loss above/Ask below/bid As %
input color sl_color = clrRed;
input color entry_color = clrAzure;

input double entry_percent_sl = 0.2; //Fixed entry as % from SL
input double fixed_entry_increase = 0.0; //Fixed entry increasing by XB length

//---
input double max_diff_sl_price = 0.3; // The max diff between SL and entry price as %
enum stoploss_mode_enum {MARKET_SL, FIXED_SL, MARKET_REGULAR_SL};
input stoploss_mode_enum stoploss_mode = FIXED_SL; // Stoploss mode if price exceed Max SL_Price differene

//--- TP configs
input double diff_sl_price_zone = 0.1; //First Zone difference from SL as %
input double tp_times = 10; //The TP will be (times) of the diff
input double diff_increases_sl = 0.1; //If the different increase as %
input double tp_decreasing = 1; //The TP (times) decreasing
input double min_tp_times = 4; //The min TP (times) of the diff

//--- Special signal
input int special_signal_count = 4; //Show special signal after x SL hit
input color tp_color = clrGreen;
color sim_tp_line_color = clrBlue;
color sim_sl_line_color = clrRed;

string Prefix = "mydraw_";



//===============================
//      Main Global variables
//===============================
bool active_set = true;
int bars_limit = 0;
pattern_type_enum pattern_type = X_A_B_C_D;
pattern_direction_enum pattern_direction = Bearish;
int b_min = 20; //B Min length index from  X
int b_max = 100; //B Max length index from x
double px_lenght_percentage = 10; //PX line % relative to XB
double min_a_to_c_btw_x_b = 0; //Min AC length % relative to XB
double max_a_to_c_btw_x_b = 100; //Max AC length % relative to XB
double min_b_to_d_btw_x_b = 0; //Min BD length % relative to XB
double max_b_to_d_btw_x_b = 100; //Max BD length % relative to XB
double min_c_to_e_btw_x_b = 0; //Min CE length % relative to XB
double max_c_to_e_btw_x_b = 100; //Max CE length % relative to XB
double max_width_percentage = 100; //Max A retrace % from X
double min_width_percentage = 0; //Min A retrace % from X
double x_to_a_b_max = 100; //Max B retrace % from XA
double x_to_a_b_min = -100; //Min B retrace % from XA
double max_width_c_xa = 1000; // Max C retrace % from XA
double min_width_c_xa = -1000; // Min C retrace % from XA
double max_width_c_ab = 200; // Max C retrace % from AB
double min_width_c_ab = -200; // Min C retrace % from AB
double max_width_d_xa = 200; // Max D retrace % from XA
double min_width_d_xa = -200; // Min D retrace % from XA
double max_width_d_bc = 200; // Max D retrace % from BC
double min_width_d_bc = -200; // Min D retrace % from BC
double max_width_e_cd = 200; // Max E retrace % from CD
double min_width_e_cd = -200; // Min E retrace % from CD
double max_width_e_xa = 1000; // Max E retrace % from XA
double min_width_e_xa = -1000; // Min E retrace % from XA
int every_increasing_of_value = 5; // Every candle count increase
double width_increasing_percentage_x_to_b = 0; //  Height increase % for XB
double width_increasing_percentage_a_e = 0; //  Max price buffer % from AC and BD and CE
double f_percentage = 50; //F Points height %
int fg_increasing_percentage = 5; // FG line increment %
double first_line_percentage = 4; //First Line %
double first_line_decrease_percentage = 0.01; //First Line Decrease %
double maxBelow_maxAbove_diff_percentage = 40; //M N approximately difference %
int mn_extension_bars = 20; //MN Extension bars count
double mn_buffer_percent = 0; //MN buffer percent
double mn_length_percent = 0;// MN Min Length percent
bool filter_candle_direction = false; // Filter Candle Direction for MN Breakout
bool filter_candle_engulf_close = false; // Filter Candle Engulfing By Close for MN Breakout
bool filter_candle_engulf_shadow = false; // Filter Candle Engulfing By Shadow for MN Breakout
bool extension_break_close = false; // Extension Break By Close
divergence_type_enum divergence_type = None_Divergence;
int tick_min_speed = 500000; //TickChart min speed


//=================================
//        Main Global struct
//=================================
struct main_global_struct
  {
   bool              active_set;
   int               bars_limit;
   pattern_type_enum pattern_type;
   pattern_direction_enum pattern_direction;
   int               b_min;
   int               b_max;
   double            px_lenght_percentage;
   double            min_a_to_c_btw_x_b;
   double            max_a_to_c_btw_x_b;
   double            min_b_to_d_btw_x_b;
   double            max_b_to_d_btw_x_b;
   double            min_c_to_e_btw_x_b;
   double            max_c_to_e_btw_x_b;
   double            max_width_percentage;
   double            min_width_percentage;
   double            x_to_a_b_max;
   double            x_to_a_b_min;
   double            max_width_c_xa;
   double            min_width_c_xa;
   double            max_width_c_ab;
   double            min_width_c_ab;
   double            max_width_d_xa;
   double            min_width_d_xa;
   double            max_width_d_bc;
   double            min_width_d_bc;
   double            max_width_e_cd;
   double            min_width_e_cd;
   double            max_width_e_xa;
   double            min_width_e_xa;
   int               every_increasing_of_value;
   double            width_increasing_percentage_x_to_b;
   double            width_increasing_percentage_a_e;
   double            f_percentage;
   int               fg_increasing_percentage;
   double            first_line_percentage;
   double            first_line_decrease_percentage;
   double            maxBelow_maxAbove_diff_percentage;
   int               mn_extension_bars;
   double            mn_buffer_percent;
   double            mn_length_percent;
   bool              filter_candle_direction;
   bool              filter_candle_engulf_close;
   bool              filter_candle_engulf_shadow;
   bool              extension_break_close;
   divergence_type_enum divergence_type;
   int               tick_min_speed;
  };



//=============================================================
//        Implementing the global sets into the structs array
//=============================================================
main_global_struct global_sets_array[];
main_global_struct set1, set2, set3, set4, set5;

//+------------------------------------------------------------------+
//|     adds inputs to the sets array
//+------------------------------------------------------------------+
void fill_sets()
  {
   ArrayFree(global_sets_array);
   set1.active_set = active_set_1;
   set1.bars_limit = bars_limit_1;
   set1.pattern_type = pattern_type_1;
   set1.pattern_direction = pattern_direction_1;
   set1.b_min = b_min_1;
   set1.b_max = b_max_1;
   set1.px_lenght_percentage = px_lenght_percentage_1;
   set1.min_a_to_c_btw_x_b = min_a_to_c_btw_x_b_1;
   set1.max_a_to_c_btw_x_b = max_a_to_c_btw_x_b_1;
   set1.min_b_to_d_btw_x_b = min_b_to_d_btw_x_b_1;
   set1.max_b_to_d_btw_x_b = max_b_to_d_btw_x_b_1;
   set1.min_c_to_e_btw_x_b = min_c_to_e_btw_x_b_1;
   set1.max_c_to_e_btw_x_b = max_c_to_e_btw_x_b_1;
   set1.max_width_percentage = max_width_percentage_1;
   set1.min_width_percentage = min_width_percentage_1;
   set1.x_to_a_b_max = x_to_a_b_max_1;
   set1.x_to_a_b_min = x_to_a_b_min_1;
   set1.max_width_c_xa = max_width_c_xa_1;
   set1.min_width_c_xa = min_width_c_xa_1;
   set1.max_width_c_ab = max_width_c_ab_1;
   set1.min_width_c_ab = min_width_c_ab_1;
   set1.max_width_d_xa = max_width_d_xa_1;
   set1.min_width_d_xa = min_width_d_xa_1;
   set1.max_width_d_bc = max_width_d_bc_1;
   set1.min_width_d_bc = min_width_d_bc_1;
   set1.max_width_e_cd = max_width_e_cd_1;
   set1.min_width_e_cd = min_width_e_cd_1;
   set1.max_width_e_xa = max_width_e_xa_1;
   set1.min_width_e_xa = min_width_e_xa_1;
   set1.every_increasing_of_value = every_increasing_of_value_1;
   set1.width_increasing_percentage_x_to_b = width_increasing_percentage_x_to_b_1;
   set1.width_increasing_percentage_a_e = width_increasing_percentage_a_e_1;
   set1.f_percentage = f_percentage_1;
   set1.fg_increasing_percentage = fg_increasing_percentage_1;
   set1.first_line_percentage = first_line_percentage_1;
   set1.first_line_decrease_percentage = first_line_decrease_percentage_1;
   set1.maxBelow_maxAbove_diff_percentage = maxBelow_maxAbove_diff_percentage_1;
   set1.mn_extension_bars = mn_extension_bars_1;
   set1.mn_buffer_percent = mn_buffer_percent_1;
   set1.mn_length_percent = mn_length_percent_1;
   set1.filter_candle_direction = filter_candle_direction_1;
   set1.filter_candle_engulf_close = filter_candle_engulf_close_1;
   set1.filter_candle_engulf_shadow = filter_candle_engulf_shadow_1;
   set1.extension_break_close = extension_break_close_1;
   set1.divergence_type = divergence_type_1;
   set1.tick_min_speed = tick_min_speed_1;
//---

   set2.active_set = active_set_2;
   set2.bars_limit = bars_limit_2;
   set2.pattern_type = pattern_type_2;
   set2.pattern_direction = pattern_direction_2;
   set2.b_min = b_min_2;
   set2.b_max = b_max_2;
   set2.px_lenght_percentage = px_lenght_percentage_2;
   set2.min_a_to_c_btw_x_b = min_a_to_c_btw_x_b_2;
   set2.max_a_to_c_btw_x_b = max_a_to_c_btw_x_b_2;
   set2.min_b_to_d_btw_x_b = min_b_to_d_btw_x_b_2;
   set2.max_b_to_d_btw_x_b = max_b_to_d_btw_x_b_2;
   set2.min_c_to_e_btw_x_b = min_c_to_e_btw_x_b_2;
   set2.max_c_to_e_btw_x_b = max_c_to_e_btw_x_b_2;
   set2.max_width_percentage = max_width_percentage_2;
   set2.min_width_percentage = min_width_percentage_2;
   set2.x_to_a_b_max = x_to_a_b_max_2;
   set2.x_to_a_b_min = x_to_a_b_min_2;
   set2.max_width_c_xa = max_width_c_xa_2;
   set2.min_width_c_xa = min_width_c_xa_2;
   set2.max_width_c_ab = max_width_c_ab_2;
   set2.min_width_c_ab = min_width_c_ab_2;
   set2.max_width_d_xa = max_width_d_xa_2;
   set2.min_width_d_xa = min_width_d_xa_2;
   set2.max_width_d_bc = max_width_d_bc_2;
   set2.min_width_d_bc = min_width_d_bc_2;
   set2.max_width_e_cd = max_width_e_cd_2;
   set2.min_width_e_cd = min_width_e_cd_2;
   set2.max_width_e_xa = max_width_e_xa_2;
   set2.min_width_e_xa = min_width_e_xa_2;
   set2.every_increasing_of_value = every_increasing_of_value_2;
   set2.width_increasing_percentage_x_to_b = width_increasing_percentage_x_to_b_2;
   set2.width_increasing_percentage_a_e = width_increasing_percentage_a_e_2;
   set2.f_percentage = f_percentage_2;
   set2.fg_increasing_percentage = fg_increasing_percentage_2;
   set2.first_line_percentage = first_line_percentage_2;
   set2.first_line_decrease_percentage = first_line_decrease_percentage_2;
   set2.maxBelow_maxAbove_diff_percentage = maxBelow_maxAbove_diff_percentage_2;
   set2.mn_extension_bars = mn_extension_bars_2;
   set2.mn_buffer_percent = mn_buffer_percent_2;
   set2.mn_length_percent = mn_length_percent_2;
   set2.filter_candle_direction = filter_candle_direction_2;
   set2.filter_candle_engulf_close = filter_candle_engulf_close_2;
   set2.filter_candle_engulf_shadow = filter_candle_engulf_shadow_2;
   set2.extension_break_close = extension_break_close_2;
   set2.divergence_type = divergence_type_2;
   set2.tick_min_speed = tick_min_speed_2;

//---

   set3.active_set = active_set_3;
   set3.bars_limit = bars_limit_3;
   set3.pattern_type = pattern_type_3;
   set3.pattern_direction = pattern_direction_3;
   set3.b_min = b_min_3;
   set3.b_max = b_max_3;
   set3.px_lenght_percentage = px_lenght_percentage_3;
   set3.min_a_to_c_btw_x_b = min_a_to_c_btw_x_b_3;
   set3.max_a_to_c_btw_x_b = max_a_to_c_btw_x_b_3;
   set3.min_b_to_d_btw_x_b = min_b_to_d_btw_x_b_3;
   set3.max_b_to_d_btw_x_b = max_b_to_d_btw_x_b_3;
   set3.min_c_to_e_btw_x_b = min_c_to_e_btw_x_b_3;
   set3.max_c_to_e_btw_x_b = max_c_to_e_btw_x_b_3;
   set3.max_width_percentage = max_width_percentage_3;
   set3.min_width_percentage = min_width_percentage_3;
   set3.x_to_a_b_max = x_to_a_b_max_3;
   set3.x_to_a_b_min = x_to_a_b_min_3;
   set3.max_width_c_xa = max_width_c_xa_3;
   set3.min_width_c_xa = min_width_c_xa_3;
   set3.max_width_c_ab = max_width_c_ab_3;
   set3.min_width_c_ab = min_width_c_ab_3;
   set3.max_width_d_xa = max_width_d_xa_3;
   set3.min_width_d_xa = min_width_d_xa_3;
   set3.max_width_d_bc = max_width_d_bc_3;
   set3.min_width_d_bc = min_width_d_bc_3;
   set3.max_width_e_cd = max_width_e_cd_3;
   set3.min_width_e_cd = min_width_e_cd_3;
   set3.max_width_e_xa = max_width_e_xa_3;
   set3.min_width_e_xa = min_width_e_xa_3;
   set3.every_increasing_of_value = every_increasing_of_value_3;
   set3.width_increasing_percentage_x_to_b = width_increasing_percentage_x_to_b_3;
   set3.width_increasing_percentage_a_e = width_increasing_percentage_a_e_3;
   set3.f_percentage = f_percentage_3;
   set3.fg_increasing_percentage = fg_increasing_percentage_3;
   set3.first_line_percentage = first_line_percentage_3;
   set3.first_line_decrease_percentage = first_line_decrease_percentage_3;
   set3.maxBelow_maxAbove_diff_percentage = maxBelow_maxAbove_diff_percentage_3;
   set3.mn_extension_bars = mn_extension_bars_3;
   set3.mn_buffer_percent = mn_buffer_percent_3;
   set3.mn_length_percent = mn_length_percent_3;
   set3.filter_candle_direction = filter_candle_direction_3;
   set3.filter_candle_engulf_close = filter_candle_engulf_close_3;
   set3.filter_candle_engulf_shadow = filter_candle_engulf_shadow_3;
   set3.extension_break_close = extension_break_close_3;
   set3.divergence_type = divergence_type_3;
   set3.tick_min_speed = tick_min_speed_3;

//---
   set4.active_set = active_set_4;
   set4.bars_limit = bars_limit_4;
   set4.pattern_type = pattern_type_4;
   set4.pattern_direction = pattern_direction_4;
   set4.b_min = b_min_4;
   set4.b_max = b_max_4;
   set4.px_lenght_percentage = px_lenght_percentage_4;
   set4.min_a_to_c_btw_x_b = min_a_to_c_btw_x_b_4;
   set4.max_a_to_c_btw_x_b = max_a_to_c_btw_x_b_4;
   set4.min_b_to_d_btw_x_b = min_b_to_d_btw_x_b_4;
   set4.max_b_to_d_btw_x_b = max_b_to_d_btw_x_b_4;
   set4.min_c_to_e_btw_x_b = min_c_to_e_btw_x_b_4;
   set4.max_c_to_e_btw_x_b = max_c_to_e_btw_x_b_4;
   set4.max_width_percentage = max_width_percentage_4;
   set4.min_width_percentage = min_width_percentage_4;
   set4.x_to_a_b_max = x_to_a_b_max_4;
   set4.x_to_a_b_min = x_to_a_b_min_4;
   set4.max_width_c_xa = max_width_c_xa_4;
   set4.min_width_c_xa = min_width_c_xa_4;
   set4.max_width_c_ab = max_width_c_ab_4;
   set4.min_width_c_ab = min_width_c_ab_4;
   set4.max_width_d_xa = max_width_d_xa_4;
   set4.min_width_d_xa = min_width_d_xa_4;
   set4.max_width_d_bc = max_width_d_bc_4;
   set4.min_width_d_bc = min_width_d_bc_4;
   set4.max_width_e_cd = max_width_e_cd_4;
   set4.min_width_e_cd = min_width_e_cd_4;
   set4.max_width_e_xa = max_width_e_xa_4;
   set4.min_width_e_xa = min_width_e_xa_4;
   set4.every_increasing_of_value = every_increasing_of_value_4;
   set4.width_increasing_percentage_x_to_b = width_increasing_percentage_x_to_b_4;
   set4.width_increasing_percentage_a_e = width_increasing_percentage_a_e_4;
   set4.f_percentage = f_percentage_4;
   set4.fg_increasing_percentage = fg_increasing_percentage_4;
   set4.first_line_percentage = first_line_percentage_4;
   set4.first_line_decrease_percentage = first_line_decrease_percentage_4;
   set4.maxBelow_maxAbove_diff_percentage = maxBelow_maxAbove_diff_percentage_4;
   set4.mn_extension_bars = mn_extension_bars_4;
   set4.mn_buffer_percent = mn_buffer_percent_4;
   set4.mn_length_percent = mn_length_percent_4;
   set4.filter_candle_direction = filter_candle_direction_4;
   set4.filter_candle_engulf_close = filter_candle_engulf_close_4;
   set4.filter_candle_engulf_shadow = filter_candle_engulf_shadow_4;
   set4.extension_break_close = extension_break_close_4;
   set4.divergence_type = divergence_type_4;
   set4.tick_min_speed = tick_min_speed_4;
//---
   set5.active_set = active_set_5;
   set5.bars_limit = bars_limit_5;
   set5.pattern_type = pattern_type_5;
   set5.pattern_direction = pattern_direction_5;
   set5.b_min = b_min_5;
   set5.b_max = b_max_5;
   set5.px_lenght_percentage = px_lenght_percentage_5;
   set5.min_a_to_c_btw_x_b = min_a_to_c_btw_x_b_5;
   set5.max_a_to_c_btw_x_b = max_a_to_c_btw_x_b_5;
   set5.min_b_to_d_btw_x_b = min_b_to_d_btw_x_b_5;
   set5.max_b_to_d_btw_x_b = max_b_to_d_btw_x_b_5;
   set5.min_c_to_e_btw_x_b = min_c_to_e_btw_x_b_5;
   set5.max_c_to_e_btw_x_b = max_c_to_e_btw_x_b_5;
   set5.max_width_percentage = max_width_percentage_5;
   set5.min_width_percentage = min_width_percentage_5;
   set5.x_to_a_b_max = x_to_a_b_max_5;
   set5.x_to_a_b_min = x_to_a_b_min_5;
   set5.max_width_c_xa = max_width_c_xa_5;
   set5.min_width_c_xa = min_width_c_xa_5;
   set5.max_width_c_ab = max_width_c_ab_5;
   set5.min_width_c_ab = min_width_c_ab_5;
   set5.max_width_d_xa = max_width_d_xa_5;
   set5.min_width_d_xa = min_width_d_xa_5;
   set5.max_width_d_bc = max_width_d_bc_5;
   set5.min_width_d_bc = min_width_d_bc_5;
   set5.max_width_e_cd = max_width_e_cd_5;
   set5.min_width_e_cd = min_width_e_cd_5;
   set5.max_width_e_xa = max_width_e_xa_5;
   set5.min_width_e_xa = min_width_e_xa_5;
   set5.every_increasing_of_value = every_increasing_of_value_5;
   set5.width_increasing_percentage_x_to_b = width_increasing_percentage_x_to_b_5;
   set5.width_increasing_percentage_a_e = width_increasing_percentage_a_e_5;
   set5.f_percentage = f_percentage_5;
   set5.fg_increasing_percentage = fg_increasing_percentage_5;
   set5.first_line_percentage = first_line_percentage_5;
   set5.first_line_decrease_percentage = first_line_decrease_percentage_5;
   set5.maxBelow_maxAbove_diff_percentage = maxBelow_maxAbove_diff_percentage_5;
   set5.mn_extension_bars = mn_extension_bars_5;
   set5.mn_buffer_percent = mn_buffer_percent_5;
   set5.mn_length_percent = mn_length_percent_5;
   set5.filter_candle_direction = filter_candle_direction_5;
   set5.filter_candle_engulf_close = filter_candle_engulf_close_5;
   set5.filter_candle_engulf_shadow = filter_candle_engulf_shadow_5;
   set5.extension_break_close = extension_break_close_5;
   set5.divergence_type = divergence_type_5;
   set5.tick_min_speed = tick_min_speed_5;
//---
   append_sets(global_sets_array, set1);
   append_sets(global_sets_array, set2);
   append_sets(global_sets_array, set3);
   append_sets(global_sets_array, set4);
   append_sets(global_sets_array, set5);
  }



//+------------------------------------------------------------------+
//|        Setting the global set
//+------------------------------------------------------------------+
void set_global_set(main_global_struct& _set)
  {
   active_set = _set.active_set;
   bars_limit = _set.bars_limit;
   pattern_type = _set.pattern_type;
   pattern_direction = _set.pattern_direction; // Pattern Direction
   b_min = _set.b_min;
   b_max = _set.b_max;
   px_lenght_percentage = _set.px_lenght_percentage;
   min_a_to_c_btw_x_b = _set.min_a_to_c_btw_x_b;
   max_a_to_c_btw_x_b = _set.max_a_to_c_btw_x_b;
   min_b_to_d_btw_x_b = _set.min_b_to_d_btw_x_b;
   max_b_to_d_btw_x_b = _set.max_b_to_d_btw_x_b;
   min_c_to_e_btw_x_b = _set.min_c_to_e_btw_x_b;
   max_c_to_e_btw_x_b = _set.max_c_to_e_btw_x_b;
   max_width_percentage = _set.max_width_percentage;
   min_width_percentage = _set.min_width_percentage;
   x_to_a_b_max = _set.x_to_a_b_max;
   x_to_a_b_min = _set.x_to_a_b_min;
   max_width_c_xa = _set.max_width_c_xa;
   min_width_c_xa = _set.min_width_c_xa;
   max_width_c_ab = _set.max_width_c_ab;
   min_width_c_ab = _set.min_width_c_ab;
   max_width_d_xa = _set.max_width_d_xa;
   min_width_d_xa = _set.min_width_d_xa;
   max_width_d_bc = _set.max_width_d_bc;
   min_width_d_bc = _set.min_width_d_bc;
   max_width_e_cd = _set.max_width_e_cd;
   min_width_e_cd = _set.min_width_e_cd;
   max_width_e_xa = _set.max_width_e_xa;
   min_width_e_xa = _set.min_width_e_xa;
   every_increasing_of_value = _set.every_increasing_of_value;
   width_increasing_percentage_x_to_b = _set.width_increasing_percentage_x_to_b;
   width_increasing_percentage_a_e = _set.width_increasing_percentage_a_e;
   f_percentage = _set.f_percentage;
   fg_increasing_percentage = _set.fg_increasing_percentage;
   first_line_percentage = _set.first_line_percentage;
   first_line_decrease_percentage = _set.first_line_decrease_percentage;
   maxBelow_maxAbove_diff_percentage = _set.maxBelow_maxAbove_diff_percentage;
   mn_extension_bars = _set.mn_extension_bars;
   mn_buffer_percent = _set.mn_buffer_percent;
   mn_length_percent = _set.mn_length_percent;
   filter_candle_direction = _set.filter_candle_direction;
   filter_candle_engulf_close = _set.filter_candle_engulf_close;
   filter_candle_engulf_shadow = _set.filter_candle_engulf_shadow;
   extension_break_close = _set.extension_break_close;
   divergence_type = _set.divergence_type;
   tick_min_speed = _set.tick_min_speed;
  }

//---
void append_sets(main_global_struct& myarray[], main_global_struct& value)
  {
   ArrayResize(myarray, ArraySize(myarray) + 1);
   myarray[ArraySize(myarray) - 1] = value;
  }
//+------------------------------------------------------------------+
