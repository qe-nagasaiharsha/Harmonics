//+------------------------------------------------------------------+
//|                                      golden_line_corrected.mq5   |
//|                        Golden Line Algorithm - Strict Definition |
//|                                                                  |
//| LAYMAN DEFINITION IMPLEMENTATION:                                |
//| BULLISH: Check below, find lowest, find highest, work with highs |
//| BEARISH: Check above, find highest, find lowest, work with lows  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "4.10"

input group "===== Pattern Type ====="

enum pattern_type_enum {X_A_B, X_A_B_C, X_A_B_C_D, X_A_B_C_D_E, X_A_B_C_D_E_F};
input pattern_type_enum pattern_type = X_A_B_C_D; // Pattern Shape type

enum pattern_direction_enum {Bearish, Bullish, Both};
input pattern_direction_enum pattern_direction = Bearish; // Pattern Direction

input group "===== Length Properties ====="

input int b_min = 20; //B Min length index from X
input int b_max = 100; //B Max length index from x

input double px_lenght_percentage = 10; //PX line % relative to XB

input double min_a_to_c_btw_x_b = 0; //Min AC length % relative to XB
input double max_a_to_c_btw_x_b = 100; //Max AC length % relative to XB

input double min_b_to_d_btw_x_b = 0; //Min BD length % relative to XB
input double max_b_to_d_btw_x_b = 100; //Max BD length % relative to XB

input double min_c_to_e_btw_x_b = 0; //Min CE length % relative to XB
input double max_c_to_e_btw_x_b = 100; //Max CE length % relative to XB

input double min_d_to_f_btw_x_b = 0; //Min DF length % relative to XB
input double max_d_to_f_btw_x_b = 100; //Max DF length % relative to XB

input group "===== Retracement of Points Properties ====="

input double max_width_percentage = 100; //Max A retrace % from X
input double min_width_percentage = 0; //Min A retrace % from X

input double x_to_a_b_max = 100; //Max B retrace % from XA
input double x_to_a_b_min = -100; //Min B retrace % from XA

input double max_width_c = 200; // Max C retrace % from AB
input double min_width_c = -200; // Min C retrace % from AB

input double max_width_d_xa = 200; // Max D retrace % from XA
input double min_width_d_xa = -200; // Min D retrace % from XA

input double max_width_d_bc = 200; // Max D retrace % from BC
input double min_width_d_bc = -200; // Min D retrace % from BC

input double max_width_e = 200; // Max E retrace % from CD
input double min_width_e = -200; // Min E retrace % from CD

input double max_width_f_xb = 200; // Max F retrace % from XB
input double min_width_f_xb = -200; // Min F retrace % from XB

input double max_width_f_de = 200; // Max F retrace % from DE
input double min_width_f_de = -200; // Min F retrace % from DE

input group "===== Dynamic height Properties ====="

input int every_increasing_of_value = 5; // Every candle count increase
input double width_increasing_percentage_x_to_b = 0; //  Height increase % for XB
input double width_increasing_percentage_a_e = 0; //  Max price buffer % from AC and BD and CE

input group "===== Golden Line Settings ====="

input double f_percentage = 50; //F Point height % (FG separator line)
input int fg_increasing_percentage = 5; // FG line increment % per iteration

input double first_line_percentage = 4; //Initial slope line %
input double first_line_decrease_percentage = 0.01; //Slope decrease % per iteration
input double maxBelow_maxAbove_diff_percentage = 40; //M N approximate equality tolerance %
input int mn_extension_bars = 20; //Golden Line extension bars count

input bool draw_golden_line = true; //Show Golden Line (MN)
input bool draw_fg_line = false; //Show FG Separator Line
input color golden_line_color = clrGold; //Golden Line Color
input color fg_line_color = clrKhaki; //FG Separator Line Color

input group "===== Filters ====="

enum divergence_type_enum  {None_Divergence, Time_Divergence, Volume_Divergence, Time_Volume_Divergence};
input divergence_type_enum divergence_type = None_Divergence;
input int tick_min_speed = 500000; //TickChart min speed

input group "===== Styles ====="
input color arrow_buy_color = clrViolet; // Buy Arrow Color
input color arrow_sell_color = clrRed; // Sell Arrow Color
input int arrow_size = 4; // Arrow Size

input bool draw_labels = true;//Show Label
input int label_font_size = 11;// Label Size
input color label_font_color = clrRed; // Label Color

input bool draw_lines = true; // Show Lines
input color px_color = clrRed; //PX Color
input color xa_color = clrOrange; //XA Color
input color ab_color = clrYellow; //AB Color
input color bc_color = clrLightBlue; //BC Color
input color cd_color = clrBlue; //CD Color
input color de_color = clrPurple; //DE Color
input color ef_color = clrMagenta; //EF Color

string Prefix = "mydraw_";

//+------------------------------------------------------------------+
//|  Wave Struct
//+------------------------------------------------------------------+

struct wave_struct
  {
   double            p_price;
   int               p_idx;

   double            x_price;
   int               x_idx;

   double            a_price;
   int               a_idx;

   double            b_price;
   int               b_idx;

   double            c_price;
   int               c_idx;

   double            d_price;
   int               d_idx;

   double            e_price;
   int               e_idx;

   double            f_price;
   int               f_idx;
  };

wave_struct my_wave_struct = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
MqlRates mrate[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   update_rates();

   if(pattern_direction == Bullish)
      phase_one();

   if(pattern_direction == Bearish)
      phase_one_bearish();

   if(pattern_direction == Both)
     {
      phase_one();
      phase_one_bearish();
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, Prefix);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
  }

//+------------------------------------------------------------------+
//| UNIFIED GOLDEN LINE - BULLISH                                    |
//| Strictly follows layman language definition                      |
//+------------------------------------------------------------------+
void golden_line_bullish(pattern_type_enum _type, wave_struct& _wave_struct)
  {
   //=================================================================
   // SETUP: Extract points and determine last point based on pattern
   //=================================================================
   double x_price = _wave_struct.x_price;
   int x_idx = _wave_struct.x_idx;
   
   double a_price = _wave_struct.a_price;
   int a_idx = _wave_struct.a_idx;
   
   double b_price = _wave_struct.b_price;
   int b_idx = _wave_struct.b_idx;
   
   double c_price = _wave_struct.c_price;
   int c_idx = _wave_struct.c_idx;
   
   double d_price = _wave_struct.d_price;
   int d_idx = _wave_struct.d_idx;
   
   double e_price = _wave_struct.e_price;
   int e_idx = _wave_struct.e_idx;
   
   double f_price = _wave_struct.f_price;
   int f_idx = _wave_struct.f_idx;
   
   // Determine last point and build intermediate points array
   double last_price;
   int last_idx;
   
   // Arrays for all intermediate points (between X and last point)
   double all_point_prices[];
   int all_point_idxs[];
   
   switch(_type)
     {
      case X_A_B:
         last_price = b_price;
         last_idx = b_idx;
         ArrayResize(all_point_prices, 1);
         ArrayResize(all_point_idxs, 1);
         all_point_prices[0] = a_price; all_point_idxs[0] = a_idx;
         break;
         
      case X_A_B_C:
         last_price = c_price;
         last_idx = c_idx;
         ArrayResize(all_point_prices, 2);
         ArrayResize(all_point_idxs, 2);
         all_point_prices[0] = a_price; all_point_idxs[0] = a_idx;
         all_point_prices[1] = b_price; all_point_idxs[1] = b_idx;
         break;
         
      case X_A_B_C_D:
         last_price = d_price;
         last_idx = d_idx;
         ArrayResize(all_point_prices, 3);
         ArrayResize(all_point_idxs, 3);
         all_point_prices[0] = a_price; all_point_idxs[0] = a_idx;
         all_point_prices[1] = b_price; all_point_idxs[1] = b_idx;
         all_point_prices[2] = c_price; all_point_idxs[2] = c_idx;
         break;
         
      case X_A_B_C_D_E:
         last_price = e_price;
         last_idx = e_idx;
         ArrayResize(all_point_prices, 4);
         ArrayResize(all_point_idxs, 4);
         all_point_prices[0] = a_price; all_point_idxs[0] = a_idx;
         all_point_prices[1] = b_price; all_point_idxs[1] = b_idx;
         all_point_prices[2] = c_price; all_point_idxs[2] = c_idx;
         all_point_prices[3] = d_price; all_point_idxs[3] = d_idx;
         break;
         
      case X_A_B_C_D_E_F:
         last_price = f_price;
         last_idx = f_idx;
         ArrayResize(all_point_prices, 5);
         ArrayResize(all_point_idxs, 5);
         all_point_prices[0] = a_price; all_point_idxs[0] = a_idx;
         all_point_prices[1] = b_price; all_point_idxs[1] = b_idx;
         all_point_prices[2] = c_price; all_point_idxs[2] = c_idx;
         all_point_prices[3] = d_price; all_point_idxs[3] = d_idx;
         all_point_prices[4] = e_price; all_point_idxs[4] = e_idx;
         break;
         
      default:
         return;
     }
   
   int num_points = ArraySize(all_point_prices);
   
   //=================================================================
   // STEP 1: Find valid baseline by checking points BELOW the line
   // "Draw line from X to F. If any ABCDE points below XF, choose 
   //  the LOWEST point. Draw new line from that point to F. Repeat."
   //=================================================================
   double baseline_start_price = x_price;
   int baseline_start_idx = x_idx;
   
   bool found_lower = true;
   while(found_lower)
     {
      found_lower = false;
      double lowest_below_price = DBL_MAX;
      int lowest_below_idx = -1;
      
      // Calculate current baseline slope
      int bars_baseline = baseline_start_idx - last_idx;
      if(bars_baseline <= 0) break;
      
      double step_baseline = (last_price - baseline_start_price) / bars_baseline;
      
      // Check ALL intermediate points between current baseline start and last point
      for(int i = 0; i < num_points; i++)
        {
         // Only check points that are between baseline_start and last_point
         if(all_point_idxs[i] >= baseline_start_idx || all_point_idxs[i] <= last_idx)
            continue;
         
         // Calculate baseline value at this point's position
         int bars_from_start = baseline_start_idx - all_point_idxs[i];
         double baseline_value_at_point = baseline_start_price + bars_from_start * step_baseline;
         
         // BULLISH: Check if point is BELOW the baseline
         if(all_point_prices[i] < baseline_value_at_point)
           {
            found_lower = true;
            // Find the LOWEST point that is below
            if(all_point_prices[i] < lowest_below_price)
              {
               lowest_below_price = all_point_prices[i];
               lowest_below_idx = all_point_idxs[i];
              }
           }
        }
      
      // If found a lower point, update baseline start
      if(found_lower && lowest_below_idx != -1)
        {
         baseline_start_price = lowest_below_price;
         baseline_start_idx = lowest_below_idx;
        }
     }
   
   //=================================================================
   // STEP 2: Use the PREVIOUS-TO-LAST point as starting point (sp)
   // For XABCD: sp = C (the point just before D)
   // For XABCDEF: sp = E (the point just before F)
   // This is the "previous last point" mentioned in the specification
   //=================================================================
   double sp_price;
   int sp_idx;
   
   // FIX: Use the LAST intermediate point (previous-to-last pattern point) as sp
   // This is the point right before the last point in the pattern
   if(num_points > 0)
     {
      // The last element in all_point_prices/idxs is the previous-to-last pattern point
      sp_price = all_point_prices[num_points - 1];
      sp_idx = all_point_idxs[num_points - 1];
     }
   else
     {
      return;  // No intermediate points
     }
   
   // Validation: sp must be between baseline_start and last_point
   if(sp_idx >= baseline_start_idx || sp_idx <= last_idx)
     {
      return;  // sp is not in valid range
     }
   
   //=================================================================
   // Calculate baseline arrays for later use
   //=================================================================
   int bars_baseline = baseline_start_idx - last_idx;
   double step_baseline = (last_price - baseline_start_price) / bars_baseline;
   
   // Create baseline array from baseline_start to last_point
   double BaselineArray[];
   ArrayResize(BaselineArray, bars_baseline + 1);
   for(int i = 0; i <= bars_baseline; i++)
     {
      BaselineArray[i] = baseline_start_price + i * step_baseline;
     }
   
   // Z point: value on baseline at sp_idx position
   int bars_to_sp = baseline_start_idx - sp_idx;
   double z_price = BaselineArray[bars_to_sp];
   int z_idx = sp_idx;
   
   //=================================================================
   // STEP 3 & 4: Draw separator line (FG) and form 2 groups
   // "Percentage calculation starts from last point, previous last point = 100%"
   // "Increase separator until 2 groups are formed"
   //=================================================================
   bool separate_found = false;
   int idxs_above_fg[];
   int idxs_below_fg[];
   double FGArray[];
   double fg_start_price;
   int fg_start_idx;
   int bars_fg;
   
   // FIX: Search BOTH directions from f_percentage to find valid separator
   // First try increasing from f_percentage, then try decreasing if not found
   int total_iterations = (int)(100 / fg_increasing_percentage) + 2;
   for(int q = 0; q <= total_iterations; q++)
     {
      ArrayFree(idxs_above_fg);
      ArrayFree(idxs_below_fg);
      ArrayFree(FGArray);
      
      // FIX: Alternate between increasing and decreasing from f_percentage
      double p_to_check;
      if(q == 0)
         p_to_check = f_percentage;
      else if(q % 2 == 1)
         p_to_check = f_percentage + ((q + 1) / 2) * fg_increasing_percentage; // Go up
      else
         p_to_check = f_percentage - (q / 2) * fg_increasing_percentage; // Go down
      
      if(p_to_check > 100) p_to_check = 100;
      if(p_to_check < 0) p_to_check = 0;
      
      // FG separator starts at percentage between baseline (0%) and sp_price (100%)
      // At Z position (on baseline at sp_idx)
      fg_start_price = z_price + (sp_price - z_price) * p_to_check * 0.01;
      fg_start_idx = z_idx;
      
      // FG line is parallel to baseline
      double step_fg = step_baseline;
      bars_fg = fg_start_idx - last_idx;
      
      ArrayResize(FGArray, bars_fg + 1);
      for(int i = 0; i <= bars_fg; i++)
        {
         FGArray[i] = fg_start_price + i * step_fg;
        }
      
      // FIX: Removed overly restrictive last bar check that was rejecting valid separations
      // The group membership check below will naturally handle classification
      
      // Classify all candle HIGHS between sp and last point into two groups
      // IMPORTANT: Include BOTH first candle (sp_idx) and last candle (last_idx)
      for(int i = 0; i <= sp_idx - last_idx; i++)
        {
         int candle_idx = sp_idx - i;
         double candle_high = iHigh(_Symbol, _Period, candle_idx);
         
         // Calculate FG value at this candle's position
         int fg_offset = i;
         if(fg_offset > bars_fg) fg_offset = bars_fg;
         double fg_value = FGArray[fg_offset];
         
         if(candle_high >= fg_value)
            append_int(idxs_above_fg, i);
         else
            append_int(idxs_below_fg, i);
        }
      
      // Need both groups to have elements
      if(ArraySize(idxs_above_fg) == 0 || ArraySize(idxs_below_fg) == 0)
         continue;
      
      separate_found = true;
      break;
     }
   
   if(!separate_found)
     {
      return;
     }
   
   //=================================================================
   // STEP 5: Matrix computation for Golden Line
   // "Draw slope from previous last point (sp). Create matrices.
   //  Find max diff in each group. If |MaxA - MaxB| < threshold, accept.
   //  Draw golden line between candle of max A and max B."
   //=================================================================
   int bars_sp_to_last = sp_idx - last_idx;
   
   // Iterate through slope values (starting from flat, increasing)
   for(int j = (int)(first_line_percentage / first_line_decrease_percentage); j >= 0; j--)
     {
      // Calculate current slope percentage
      double current_slope_pct = first_line_percentage - j * first_line_decrease_percentage;
      
      // Create slope line array starting from sp_price going toward last point
      // Slope line: starts at sp_price and decreases by slope amount per bar
      double slope_per_bar = (sp_price * current_slope_pct * 0.01) / bars_sp_to_last;
      
      double SlopeLineArray[];
      ArrayResize(SlopeLineArray, bars_sp_to_last + 1);
      for(int i = 0; i <= bars_sp_to_last; i++)
        {
         // BULLISH: slope line decreases from sp_price
         SlopeLineArray[i] = sp_price - slope_per_bar * i;
        }
      
      // Matrix3 = ActualHigh - SlopeLine (for each candle)
      // Divide into Group A (above FG) and Group B (below FG)
      
      double above_diff_array[];
      int above_diff_idx_array[];
      double below_diff_array[];
      int below_diff_idx_array[];
      
      // Group A: candles above FG line
      for(int i = 0; i < ArraySize(idxs_above_fg); i++)
        {
         int offset = idxs_above_fg[i];
         int candle_idx = sp_idx - offset;
         double actual_high = iHigh(_Symbol, _Period, candle_idx);
         double slope_value = SlopeLineArray[offset];
         double diff = actual_high - slope_value;
         
         append_double(above_diff_array, diff);
         append_int(above_diff_idx_array, offset);
        }
      
      // Group B: candles below FG line
      for(int i = 0; i < ArraySize(idxs_below_fg); i++)
        {
         int offset = idxs_below_fg[i];
         int candle_idx = sp_idx - offset;
         double actual_high = iHigh(_Symbol, _Period, candle_idx);
         double slope_value = SlopeLineArray[offset];
         double diff = actual_high - slope_value;
         
         append_double(below_diff_array, diff);
         append_int(below_diff_idx_array, offset);
        }
      
      // Validation
      if(ArraySize(above_diff_array) == 0 || ArraySize(below_diff_array) == 0)
         continue;
      
      // Find MAX diff in each group
      double max_above_diff = above_diff_array[ArrayMaximum(above_diff_array)];
      double max_below_diff = below_diff_array[ArrayMaximum(below_diff_array)];
      
      // FIX: Improved tolerance calculation with better edge case handling
      // Use average of both values as base for percentage calculation (more balanced)
      double avg_diff = (MathAbs(max_above_diff) + MathAbs(max_below_diff)) / 2.0;
      double diff_percentage;
      
      // If both are essentially zero or very small, consider them equal
      if(avg_diff < _Point * 10)
         diff_percentage = 0;
      else
         diff_percentage = MathAbs(max_above_diff - max_below_diff) / avg_diff;
      
      // Check if within tolerance (apply tolerance percentage directly)
      if(diff_percentage > maxBelow_maxAbove_diff_percentage * 0.01)
         continue;
      
      // FOUND VALID GOLDEN LINE!
      // Get M and N points (candles with max diff in each group)
      int max_above_offset = above_diff_idx_array[ArrayMaximum(above_diff_array)];
      int max_below_offset = below_diff_idx_array[ArrayMaximum(below_diff_array)];
      
      int m_idx = sp_idx - max_above_offset;  // M point candle index
      int n_idx = sp_idx - max_below_offset;  // N point candle index
      
      double m_price = iHigh(_Symbol, _Period, m_idx);
      double n_price = iHigh(_Symbol, _Period, n_idx);
      
      // FIX #2: Ensure M comes before N (earlier in time = larger index)
      // If not, swap them so golden line is drawn consistently
      if(m_idx < n_idx)
        {
         int temp_idx = m_idx;
         m_idx = n_idx;
         n_idx = temp_idx;
         
         double temp_price = m_price;
         m_price = n_price;
         n_price = temp_price;
        }
      
      // FIX #3: Skip if M and N are the same candle
      if(m_idx == n_idx)
         continue;
      
      // Calculate Golden Line (MN line) and extend
      int bars_m_n = m_idx - n_idx;
      double step_mn = (n_price - m_price) / bars_m_n;
      
      double MNArray[];
      int mn_total_bars = m_idx - last_idx + mn_extension_bars;
      ArrayResize(MNArray, mn_total_bars);
      for(int i = 0; i < mn_total_bars; i++)
        {
         MNArray[i] = m_price + i * step_mn;
        }
      
      // Create baseline extension for breakout check
      double BaselineExtArray[];
      int baseline_ext_total = bars_baseline + mn_extension_bars;
      ArrayResize(BaselineExtArray, baseline_ext_total);
      for(int i = 0; i < baseline_ext_total; i++)
        {
         if(i <= bars_baseline)
            BaselineExtArray[i] = BaselineArray[i];
         else
            BaselineExtArray[i] = last_price + (i - bars_baseline) * step_baseline;
        }
      
      // Search for breakout signal after last point
      for(int i = 1; i < mn_extension_bars; i++)
        {
         int signal_idx = last_idx - i;
         
         if(signal_idx < 1)
            break;
         
         // MN value at this position
         int mn_offset = m_idx - last_idx + i;
         if(mn_offset >= ArraySize(MNArray))
            break;
         double trend_price = MNArray[mn_offset];
         
         // Baseline extension value at this position
         int baseline_ext_offset = bars_baseline + i;
         if(baseline_ext_offset >= ArraySize(BaselineExtArray))
            break;
         double baseline_ext_price = BaselineExtArray[baseline_ext_offset];
         
         double candle_high = mrate[signal_idx].high;
         double candle_low = mrate[signal_idx].low;
         double candle_close = mrate[signal_idx].close;
         
         // BULLISH: Price must not go below baseline extension
         if(candle_low < baseline_ext_price)
            break;
         
         // BULLISH: Close must break above golden line
         if(candle_close <= trend_price)
            continue;
         
         // Signal found - draw buy arrow
         draw_arrow("buy", signal_idx, candle_low);
         break;
        }
      
      // Draw lines if enabled
      if(draw_lines)
        {
         int ext_bars = mn_extension_bars;
         if(last_idx - mn_extension_bars < 0)
            ext_bars = last_idx;
         
         // Draw FG Separator Line
         if(draw_fg_line && ArraySize(FGArray) > 0)
            draw_line("fg", 0, fg_start_idx, fg_start_price, last_idx, FGArray[bars_fg], fg_line_color);
         
         // Draw Golden Line (MN line)
         if(draw_golden_line)
           {
            int mn_end_offset = m_idx - last_idx + ext_bars - 1;
            if(mn_end_offset < ArraySize(MNArray))
               draw_line("golden", 0, m_idx, m_price, last_idx - ext_bars + 1, MNArray[mn_end_offset], golden_line_color);
           }
        }
      
      return;
     }
  }


//+------------------------------------------------------------------+
//| UNIFIED GOLDEN LINE - BEARISH (Reverse of Bullish)               |
//| STEP 1: Check if points ABOVE baseline, find HIGHEST             |
//| STEP 2: Find LOWEST point between baseline start and last point  |
//| STEP 5: Work with LOWS for golden line                           |
//+------------------------------------------------------------------+
void golden_line_bearish(pattern_type_enum _type, wave_struct& _wave_struct)
  {
   //=================================================================
   // SETUP: Extract points and determine last point based on pattern
   //=================================================================
   double x_price = _wave_struct.x_price;
   int x_idx = _wave_struct.x_idx;
   
   double a_price = _wave_struct.a_price;
   int a_idx = _wave_struct.a_idx;
   
   double b_price = _wave_struct.b_price;
   int b_idx = _wave_struct.b_idx;
   
   double c_price = _wave_struct.c_price;
   int c_idx = _wave_struct.c_idx;
   
   double d_price = _wave_struct.d_price;
   int d_idx = _wave_struct.d_idx;
   
   double e_price = _wave_struct.e_price;
   int e_idx = _wave_struct.e_idx;
   
   double f_price = _wave_struct.f_price;
   int f_idx = _wave_struct.f_idx;
   
   // Determine last point and build intermediate points array
   double last_price;
   int last_idx;
   
   double all_point_prices[];
   int all_point_idxs[];
   
   switch(_type)
     {
      case X_A_B:
         last_price = b_price;
         last_idx = b_idx;
         ArrayResize(all_point_prices, 1);
         ArrayResize(all_point_idxs, 1);
         all_point_prices[0] = a_price; all_point_idxs[0] = a_idx;
         break;
         
      case X_A_B_C:
         last_price = c_price;
         last_idx = c_idx;
         ArrayResize(all_point_prices, 2);
         ArrayResize(all_point_idxs, 2);
         all_point_prices[0] = a_price; all_point_idxs[0] = a_idx;
         all_point_prices[1] = b_price; all_point_idxs[1] = b_idx;
         break;
         
      case X_A_B_C_D:
         last_price = d_price;
         last_idx = d_idx;
         ArrayResize(all_point_prices, 3);
         ArrayResize(all_point_idxs, 3);
         all_point_prices[0] = a_price; all_point_idxs[0] = a_idx;
         all_point_prices[1] = b_price; all_point_idxs[1] = b_idx;
         all_point_prices[2] = c_price; all_point_idxs[2] = c_idx;
         break;
         
      case X_A_B_C_D_E:
         last_price = e_price;
         last_idx = e_idx;
         ArrayResize(all_point_prices, 4);
         ArrayResize(all_point_idxs, 4);
         all_point_prices[0] = a_price; all_point_idxs[0] = a_idx;
         all_point_prices[1] = b_price; all_point_idxs[1] = b_idx;
         all_point_prices[2] = c_price; all_point_idxs[2] = c_idx;
         all_point_prices[3] = d_price; all_point_idxs[3] = d_idx;
         break;
         
      case X_A_B_C_D_E_F:
         last_price = f_price;
         last_idx = f_idx;
         ArrayResize(all_point_prices, 5);
         ArrayResize(all_point_idxs, 5);
         all_point_prices[0] = a_price; all_point_idxs[0] = a_idx;
         all_point_prices[1] = b_price; all_point_idxs[1] = b_idx;
         all_point_prices[2] = c_price; all_point_idxs[2] = c_idx;
         all_point_prices[3] = d_price; all_point_idxs[3] = d_idx;
         all_point_prices[4] = e_price; all_point_idxs[4] = e_idx;
         break;
         
      default:
         return;
     }
   
   int num_points = ArraySize(all_point_prices);
   
   //=================================================================
   // STEP 1: Find valid baseline by checking points ABOVE the line
   // BEARISH: Check if points are ABOVE, find HIGHEST
   //=================================================================
   double baseline_start_price = x_price;
   int baseline_start_idx = x_idx;
   
   bool found_higher = true;
   while(found_higher)
     {
      found_higher = false;
      double highest_above_price = -DBL_MAX;
      int highest_above_idx = -1;
      
      int bars_baseline = baseline_start_idx - last_idx;
      if(bars_baseline <= 0) break;
      
      double step_baseline = (last_price - baseline_start_price) / bars_baseline;
      
      for(int i = 0; i < num_points; i++)
        {
         if(all_point_idxs[i] >= baseline_start_idx || all_point_idxs[i] <= last_idx)
            continue;
         
         int bars_from_start = baseline_start_idx - all_point_idxs[i];
         double baseline_value_at_point = baseline_start_price + bars_from_start * step_baseline;
         
         // BEARISH: Check if point is ABOVE the baseline
         if(all_point_prices[i] > baseline_value_at_point)
           {
            found_higher = true;
            // Find the HIGHEST point that is above
            if(all_point_prices[i] > highest_above_price)
              {
               highest_above_price = all_point_prices[i];
               highest_above_idx = all_point_idxs[i];
              }
           }
        }
      
      if(found_higher && highest_above_idx != -1)
        {
         baseline_start_price = highest_above_price;
         baseline_start_idx = highest_above_idx;
        }
     }
   
   //=================================================================
   // STEP 2: Use the PREVIOUS-TO-LAST point as starting point (sp)
   // For XABCD: sp = C (the point just before D)
   // For XABCDEF: sp = E (the point just before F)
   // This is the "previous last point" mentioned in the specification
   //=================================================================
   double sp_price;
   int sp_idx;
   
   // FIX: Use the LAST intermediate point (previous-to-last pattern point) as sp
   if(num_points > 0)
     {
      sp_price = all_point_prices[num_points - 1];
      sp_idx = all_point_idxs[num_points - 1];
     }
   else
     {
      return;
     }
   
   // Validation: sp must be between baseline_start and last_point
   if(sp_idx >= baseline_start_idx || sp_idx <= last_idx)
     {
      return;
     }
   
   //=================================================================
   // Calculate baseline arrays
   //=================================================================
   int bars_baseline = baseline_start_idx - last_idx;
   double step_baseline = (last_price - baseline_start_price) / bars_baseline;
   
   double BaselineArray[];
   ArrayResize(BaselineArray, bars_baseline + 1);
   for(int i = 0; i <= bars_baseline; i++)
     {
      BaselineArray[i] = baseline_start_price + i * step_baseline;
     }
   
   int bars_to_sp = baseline_start_idx - sp_idx;
   double z_price = BaselineArray[bars_to_sp];
   int z_idx = sp_idx;
   
   //=================================================================
   // STEP 3 & 4: Separator line for BEARISH
   // Separator divides LOWS into two groups
   //=================================================================
   bool separate_found = false;
   int idxs_above_fg[];
   int idxs_below_fg[];
   double FGArray[];
   double fg_start_price;
   int fg_start_idx;
   int bars_fg;
   
   // FIX: Search BOTH directions from f_percentage to find valid separator
   int total_iterations = (int)(100 / fg_increasing_percentage) + 2;
   for(int q = 0; q <= total_iterations; q++)
     {
      ArrayFree(idxs_above_fg);
      ArrayFree(idxs_below_fg);
      ArrayFree(FGArray);
      
      // FIX: Alternate between increasing and decreasing from f_percentage
      double p_to_check;
      if(q == 0)
         p_to_check = f_percentage;
      else if(q % 2 == 1)
         p_to_check = f_percentage + ((q + 1) / 2) * fg_increasing_percentage;
      else
         p_to_check = f_percentage - (q / 2) * fg_increasing_percentage;
      
      if(p_to_check > 100) p_to_check = 100;
      if(p_to_check < 0) p_to_check = 0;
      
      // BEARISH: FG between baseline (100%) and sp_price (0%)
      // sp is LOW, so FG is between z_price and sp_price
      fg_start_price = z_price - (z_price - sp_price) * p_to_check * 0.01;
      fg_start_idx = z_idx;
      
      double step_fg = step_baseline;
      bars_fg = fg_start_idx - last_idx;
      
      ArrayResize(FGArray, bars_fg + 1);
      for(int i = 0; i <= bars_fg; i++)
        {
         FGArray[i] = fg_start_price + i * step_fg;
        }
      
      // FIX: Removed overly restrictive last bar check that was rejecting valid separations
      // The group membership check below will naturally handle classification
      
      // Classify LOWS into two groups
      // IMPORTANT: Include BOTH first candle (sp_idx) and last candle (last_idx)
      for(int i = 0; i <= sp_idx - last_idx; i++)
        {
         int candle_idx = sp_idx - i;
         double candle_low = iLow(_Symbol, _Period, candle_idx);
         
         int fg_offset = i;
         if(fg_offset > bars_fg) fg_offset = bars_fg;
         double fg_value = FGArray[fg_offset];
         
         // BEARISH: above FG means LOW > FG (price is higher)
         if(candle_low > fg_value)
            append_int(idxs_above_fg, i);
         else
            append_int(idxs_below_fg, i);
        }
      
      if(ArraySize(idxs_above_fg) == 0 || ArraySize(idxs_below_fg) == 0)
         continue;
      
      separate_found = true;
      break;
     }
   
   if(!separate_found)
     {
      return;
     }
   
   //=================================================================
   // STEP 5: Matrix computation for BEARISH Golden Line
   // Work with LOWS instead of HIGHS
   //=================================================================
   int bars_sp_to_last = sp_idx - last_idx;
   
   for(int j = (int)(first_line_percentage / first_line_decrease_percentage); j >= 0; j--)
     {
      double current_slope_pct = first_line_percentage - j * first_line_decrease_percentage;
      
      double slope_per_bar = (sp_price * current_slope_pct * 0.01) / bars_sp_to_last;
      
      double SlopeLineArray[];
      ArrayResize(SlopeLineArray, bars_sp_to_last + 1);
      for(int i = 0; i <= bars_sp_to_last; i++)
        {
         // BEARISH: slope line increases from sp_price (going toward higher prices)
         SlopeLineArray[i] = sp_price + slope_per_bar * i;
        }
      
      // Matrix3 = SlopeLine - ActualLow (for bearish, we want low to be below slope)
      double above_diff_array[];
      int above_diff_idx_array[];
      double below_diff_array[];
      int below_diff_idx_array[];
      
      // Group A: candles with lows above FG line (higher lows)
      for(int i = 0; i < ArraySize(idxs_above_fg); i++)
        {
         int offset = idxs_above_fg[i];
         int candle_idx = sp_idx - offset;
         double actual_low = iLow(_Symbol, _Period, candle_idx);
         double slope_value = SlopeLineArray[offset];
         double diff = slope_value - actual_low;  // BEARISH: how far below slope
         
         append_double(above_diff_array, diff);
         append_int(above_diff_idx_array, offset);
        }
      
      // Group B: candles with lows below FG line (lower lows)
      for(int i = 0; i < ArraySize(idxs_below_fg); i++)
        {
         int offset = idxs_below_fg[i];
         int candle_idx = sp_idx - offset;
         double actual_low = iLow(_Symbol, _Period, candle_idx);
         double slope_value = SlopeLineArray[offset];
         double diff = slope_value - actual_low;
         
         append_double(below_diff_array, diff);
         append_int(below_diff_idx_array, offset);
        }
      
      if(ArraySize(above_diff_array) == 0 || ArraySize(below_diff_array) == 0)
         continue;
      
      double max_above_diff = above_diff_array[ArrayMaximum(above_diff_array)];
      double max_below_diff = below_diff_array[ArrayMaximum(below_diff_array)];
      
      // FIX: Improved tolerance calculation with better edge case handling
      // Use average of both values as base for percentage calculation (more balanced)
      double avg_diff = (MathAbs(max_above_diff) + MathAbs(max_below_diff)) / 2.0;
      double diff_percentage;
      
      // If both are essentially zero or very small, consider them equal
      if(avg_diff < _Point * 10)
         diff_percentage = 0;
      else
         diff_percentage = MathAbs(max_above_diff - max_below_diff) / avg_diff;
      
      if(diff_percentage > maxBelow_maxAbove_diff_percentage * 0.01)
         continue;
      
      // FOUND VALID GOLDEN LINE!
      int max_above_offset = above_diff_idx_array[ArrayMaximum(above_diff_array)];
      int max_below_offset = below_diff_idx_array[ArrayMaximum(below_diff_array)];
      
      int m_idx = sp_idx - max_above_offset;  // M from above FG group
      int n_idx = sp_idx - max_below_offset;  // N from below FG group
      
      double m_price = iLow(_Symbol, _Period, m_idx);  // BEARISH: use lows
      double n_price = iLow(_Symbol, _Period, n_idx);
      
      // FIX #2: Ensure M comes before N (earlier in time = larger index)
      // If not, swap them so golden line is drawn consistently
      if(m_idx < n_idx)
        {
         int temp_idx = m_idx;
         m_idx = n_idx;
         n_idx = temp_idx;
         
         double temp_price = m_price;
         m_price = n_price;
         n_price = temp_price;
        }
      
      // FIX #3: Skip if M and N are the same candle
      if(m_idx == n_idx)
         continue;
      
      // Calculate Golden Line (MN line) and extend
      int bars_m_n = m_idx - n_idx;
      double step_mn = (n_price - m_price) / bars_m_n;
      
      double MNArray[];
      int mn_total_bars = m_idx - last_idx + mn_extension_bars;
      ArrayResize(MNArray, mn_total_bars);
      for(int i = 0; i < mn_total_bars; i++)
        {
         MNArray[i] = m_price + i * step_mn;
        }
      
      // Baseline extension
      double BaselineExtArray[];
      int baseline_ext_total = bars_baseline + mn_extension_bars;
      ArrayResize(BaselineExtArray, baseline_ext_total);
      for(int i = 0; i < baseline_ext_total; i++)
        {
         if(i <= bars_baseline)
            BaselineExtArray[i] = BaselineArray[i];
         else
            BaselineExtArray[i] = last_price + (i - bars_baseline) * step_baseline;
        }
      
      // Search for breakout signal
      for(int i = 1; i < mn_extension_bars; i++)
        {
         int signal_idx = last_idx - i;
         
         if(signal_idx < 1)
            break;
         
         // MN value at this position (offset from M)
         int mn_offset = m_idx - last_idx + i;
         if(mn_offset >= ArraySize(MNArray))
            break;
         double trend_price = MNArray[mn_offset];
         
         int baseline_ext_offset = bars_baseline + i;
         if(baseline_ext_offset >= ArraySize(BaselineExtArray))
            break;
         double baseline_ext_price = BaselineExtArray[baseline_ext_offset];
         
         double candle_high = mrate[signal_idx].high;
         double candle_low = mrate[signal_idx].low;
         double candle_close = mrate[signal_idx].close;
         
         // BEARISH: Price must not go above baseline extension
         if(candle_high > baseline_ext_price)
            break;
         
         // BEARISH: Close must break below golden line
         if(candle_close >= trend_price)
            continue;
         
         // Signal found - draw sell arrow
         draw_arrow("sell", signal_idx, candle_high);
         break;
        }
      
      if(draw_lines)
        {
         int ext_bars = mn_extension_bars;
         if(last_idx - mn_extension_bars < 0)
            ext_bars = last_idx;
         
         if(draw_fg_line && ArraySize(FGArray) > 0)
            draw_line("fg", 0, fg_start_idx, fg_start_price, last_idx, FGArray[bars_fg], fg_line_color);
         
         if(draw_golden_line)
           {
            // Draw golden line from M extending toward last_idx and beyond
            int mn_end_offset = m_idx - last_idx + ext_bars - 1;
            if(mn_end_offset < ArraySize(MNArray))
               draw_line("golden", 0, m_idx, m_price, last_idx - ext_bars + 1, MNArray[mn_end_offset], golden_line_color);
           }
        }
      
      return;
     }
  }


//+------------------------------------------------------------------+
//| PHASE TWO - Routes to appropriate golden line function           |
//+------------------------------------------------------------------+
void phase_two(pattern_type_enum _type, wave_struct& _wave_struct)
  {
   golden_line_bullish(_type, _wave_struct);
  }

void phase_two_bearish(pattern_type_enum _type, wave_struct& _wave_struct)
  {
   golden_line_bearish(_type, _wave_struct);
  }


//+------------------------------------------------------------------+
//| PHASE ONE BULLISH - Pattern Detection                            |
//+------------------------------------------------------------------+
void phase_one()
  {
   draw_progress("Updating ...", clrGray);

   string _symbol = _Symbol;
   ENUM_TIMEFRAMES _period = _Period;

   int x_bars = Bars(_symbol, _period) - 1;

   for(int x_idx = x_bars ; x_idx > 0; x_idx--)
     {
      double x_price = iLow(_symbol, _period, x_idx);
      if(x_price == 0)
         continue;

      double dynamic_max_width_percentage;
      double dynamic_min_width_percentage;

      int b_start_idx = x_idx - 1 - b_min;

      my_wave_struct.x_idx = x_idx;
      my_wave_struct.x_price = x_price;

      for(int b_idx = b_start_idx; b_idx > x_idx - b_max; b_idx--)
        {
         double b_price = iLow(_symbol, _period, b_idx);
         int bars_x_b = x_idx - b_idx;
         double StepXB;
         double XBArray[];
         bool _continue_b = false;

         StepXB = (b_price - x_price) / bars_x_b;
         for(int j = 1; j <= bars_x_b; j++)
           {
            append_double(XBArray, (x_price + j * StepXB));
           }

         int bars_p_x = int(px_lenght_percentage * 0.01 * bars_x_b);

         if(x_bars - x_idx < bars_p_x)
            break;

         int p_idx = x_idx + bars_p_x;
         double p_price = x_price - (bars_p_x * StepXB);

         double px_array[];
         for(int px_array_idx = 0; px_array_idx < bars_x_b; px_array_idx++)
           {
            append_double(px_array, p_price + px_array_idx * StepXB);
           }

         for(int px_idx = 0 ; px_idx < bars_p_x; px_idx++)
           {
            int real_p_idx = x_idx + 1 + px_idx;
            double p_bar_low = iLow(_symbol, _period, real_p_idx);
            double p_array_value = px_array[bars_p_x - 1 - px_idx];

            if(p_bar_low < p_array_value)
              {
               _continue_b = true;
               break;
              }
           }

         if(_continue_b)
            continue;

         for(int xb_idx = 0 ; xb_idx < bars_x_b; xb_idx++)
           {
            int real_b_idx = x_idx - xb_idx - 1 ;
            double b_bar_low = iLow(_symbol, _period, real_b_idx);
            double b_array_value = XBArray[xb_idx];

            if(b_bar_low < b_array_value)
              {
               _continue_b = true;
               break;
              }
           }

         if(_continue_b)
            continue;

         my_wave_struct.b_idx = b_idx;
         my_wave_struct.b_price = b_price;

         my_wave_struct.p_idx = p_idx;
         my_wave_struct.p_price = p_price;

         // Calculation A Point
         double ab_diff_array[];
         for(int ab_idx = 0; ab_idx < bars_x_b; ab_idx++)
           {
            double ab_diff = iHigh(_symbol, _period, x_idx - ab_idx) - XBArray[ab_idx];
            append_double(ab_diff_array,  ab_diff);
           }

         int a_idx =  x_idx - ArrayMaximum(ab_diff_array);
         double a_price = iHigh(_symbol, _period, a_idx);

         double max_val = x_price + (a_price - x_price) * x_to_a_b_max * 0.01;
         double min_val = x_price + (a_price - x_price) * x_to_a_b_min * 0.01;

         if(b_price > max_val || b_price < min_val)
            continue;

         int _tmp_a_idx = a_idx;
         if(b_price > x_price)
           {
            for(int high_a = a_idx; high_a > b_idx; high_a--)
              {
               double high_a_price = iHigh(_symbol, _period, high_a);
               if(high_a_price > a_price)
                 {
                  _tmp_a_idx = high_a;
                  a_price = high_a_price;
                 }
              }
           }
         else
           {
            for(int high_a = x_idx ; high_a >= a_idx; high_a--)
              {
               double high_a_price = iHigh(_symbol, _period, high_a);
               if(high_a_price > a_price)
                 {
                  _tmp_a_idx = high_a;
                  a_price = high_a_price;
                 }
              }
           }
         a_idx = _tmp_a_idx;

         int dynamic_candles_count = b_start_idx - b_idx;
         double increasing_width_value = ((int)(dynamic_candles_count / every_increasing_of_value) + 1) * width_increasing_percentage_x_to_b;
         dynamic_max_width_percentage = max_width_percentage + increasing_width_value;
         dynamic_min_width_percentage = min_width_percentage + increasing_width_value;

         double z = XBArray[x_idx - a_idx];
         double a_upper_boundary = (z * dynamic_max_width_percentage * 0.01) + z;
         double a_lower_boundary = (z * dynamic_min_width_percentage * 0.01) + z;
         if(a_price > a_upper_boundary || a_price < a_lower_boundary)
            continue;

         my_wave_struct.a_idx = a_idx;
         my_wave_struct.a_price = a_price;

         if(pattern_type == X_A_B)
           {
            if(!divergence_filter(x_idx, a_idx, b_idx, -1))
               continue;

            if(!tick_speed_filter(x_idx, b_idx))
               continue;

            if(draw_lines)
               draw_pattern(X_A_B, my_wave_struct);

            if(draw_labels)
              {
               draw_label("X", "X", x_idx, -1);
               draw_label("A", "A", a_idx, 1);
               draw_label("B", "B", b_idx, -1);
              }

            phase_two(X_A_B, my_wave_struct);
            continue;
           }

         // Calculating C Point
         int c_min_idx = a_idx - (int)(bars_x_b * min_a_to_c_btw_x_b * 0.01);
         int c_max_idx = a_idx - (int)(bars_x_b * max_a_to_c_btw_x_b * 0.01);
         if(c_min_idx >= b_idx)
            c_min_idx = b_idx - 1;

         double BCArray[];
         for(int bc_idx = 1; bc_idx <= b_idx - c_max_idx; bc_idx++)
           {
            append_double(BCArray, b_price +  bc_idx * StepXB);
           }

         double c_upper_boundary = b_price + (a_price - b_price) * max_width_c * 0.01;
         double c_lower_boundary = b_price + (a_price - b_price) * min_width_c * 0.01;

         for(int c_idx = c_min_idx; c_idx > c_max_idx; c_idx--)
           {
            bool _continue_c = false;
            double current_c_low = iLow(_symbol, _period, c_idx);
            double c_price = iHigh(_symbol, _period, c_idx);
            int bars_a_c = a_idx - c_idx;

            for(int i = 0; i < b_idx - c_idx; i++)
              {
               double tmp_low = iLow(_symbol, _period, b_idx - i - 1);
               double tmp_bc_val = BCArray[i];
               if(tmp_low < tmp_bc_val)
                 {
                  _continue_c = true;
                  break;
                 }
              }

            if(_continue_c)
               continue;

            if(c_price > c_upper_boundary || c_price < c_lower_boundary)
              {
               continue;
              }

            double StepAC = (c_price - a_price) / bars_a_c;
            double ACArray[];
            double New_ACArray[];
            for(int j = 1; j <= bars_a_c; j++)
              {
               int idx = (int)((b_start_idx - b_idx) / every_increasing_of_value);
               double real_ac_val = (a_price + j * StepAC);
               append_double(ACArray, real_ac_val);
               append_double(New_ACArray, real_ac_val + real_ac_val * idx * width_increasing_percentage_a_e * 0.01);
              }

            for(int i = 0; i < bars_a_c; i++)
              {
               double new_ac_array_val = New_ACArray[i];
               double temp_c_val = iHigh(_symbol, _period, a_idx - i - 1);
               if(temp_c_val > new_ac_array_val)
                 {
                  _continue_c = true;
                  break;
                 }
              }

            if(_continue_c)
               continue;

            my_wave_struct.c_idx = c_idx;
            my_wave_struct.c_price = c_price;

            if(pattern_type == X_A_B_C)
              {
               if(!divergence_filter(a_idx, b_idx, c_idx, 1))
                  continue;

               if(!tick_speed_filter(x_idx, c_idx))
                  continue;

               if(draw_lines)
                  draw_pattern(X_A_B_C, my_wave_struct);

               if(draw_labels)
                 {
                  draw_label("X", "X", x_idx, -1);
                  draw_label("A", "A", a_idx, 1);
                  draw_label("B", "B", b_idx, -1);
                  draw_label("C", "C", c_idx, 1);
                 }

               phase_two(X_A_B_C, my_wave_struct);
               continue;
              }

            // Calculating D Point
            int d_min_idx = b_idx - (int)(bars_x_b * min_b_to_d_btw_x_b * 0.01);
            int d_max_idx = b_idx - (int)(bars_x_b * max_b_to_d_btw_x_b * 0.01);
            if(d_min_idx >= c_idx)
               d_min_idx = c_idx - 1;

            double ACArrayExt[];
            for(int i = 1; i <= b_idx - d_max_idx; i++)
              {
               append_double(ACArrayExt, c_price +  i * StepAC);
              }

            double d_upper_boundary_bc = b_price + (c_price - b_price) * max_width_d_bc * 0.01;
            double d_lower_boundary_bc = b_price + (c_price - b_price) * min_width_d_bc * 0.01;

            double d_upper_boundary_xa = x_price + (a_price - x_price) * max_width_d_xa * 0.01;
            double d_lower_boundary_xa = x_price + (a_price - x_price) * min_width_d_xa * 0.01;

            for(int d_idx = d_min_idx; d_idx > d_max_idx; d_idx--)
              {

               bool _continue_d = false;
               double current_d_low = iLow(_symbol, _period, d_idx);
               double d_price = iLow(_symbol, _period, d_idx);
               int bars_b_d = b_idx - d_idx;

               for(int i = 0; i < c_idx - d_idx; i++)
                 {
                  double tmp_high = iHigh(_symbol, _period, c_idx - i - 1);
                  double tmp_ac_val = ACArrayExt[i];
                  if(tmp_high > tmp_ac_val)
                    {
                     _continue_d = true;
                     break;
                    }
                 }

               if(_continue_d)
                  continue;

               if(d_price > d_upper_boundary_bc || d_price < d_lower_boundary_bc)
                 {
                  continue;
                 }

               if(d_price > d_upper_boundary_xa || d_price < d_lower_boundary_xa)
                 {
                  continue;
                 }

               double StepBD = (d_price - b_price) / bars_b_d;
               double BDArray[];
               double New_BDArray[];
               for(int j = 1; j <= bars_b_d; j++)
                 {
                  int idx = (int)((b_start_idx - b_idx) / every_increasing_of_value);
                  double real_bd_val = (b_price + j * StepBD);
                  append_double(BDArray, real_bd_val);
                  append_double(New_BDArray, real_bd_val - real_bd_val * idx * width_increasing_percentage_a_e * 0.01);
                 }

               for(int i = 0; i < bars_b_d; i++)
                 {
                  double new_bd_array_val = New_BDArray[i];
                  double temp_d_val = iLow(_symbol, _period, b_idx - i - 1);
                  if(temp_d_val < new_bd_array_val)
                    {
                     _continue_d = true;
                     break;
                    }
                 }

               if(_continue_d)
                  continue;

               my_wave_struct.d_idx = d_idx;
               my_wave_struct.d_price = d_price;

               if(pattern_type == X_A_B_C_D)
                 {
                  if(!divergence_filter(b_idx, c_idx, d_idx, -1))
                     continue;

                  if(!tick_speed_filter(x_idx, d_idx))
                     continue;

                  if(draw_lines)
                     draw_pattern(X_A_B_C_D, my_wave_struct);

                  if(draw_labels)
                    {
                     draw_label("X", "X", x_idx, -1);
                     draw_label("A", "A", a_idx, 1);
                     draw_label("B", "B", b_idx, -1);
                     draw_label("C", "C", c_idx, 1);
                     draw_label("D", "D", d_idx, -1);
                    }

                  phase_two(X_A_B_C_D, my_wave_struct);
                  continue;
                 }

               // Calculating E Point
               int e_min_idx = c_idx - (int)(bars_x_b * min_c_to_e_btw_x_b * 0.01);
               int e_max_idx = c_idx - (int)(bars_x_b * max_c_to_e_btw_x_b * 0.01);
               if(e_min_idx >= d_idx)
                  e_min_idx = d_idx - 1;

               double BDArrayExt[];
               for(int i = 1; i <= d_idx - e_max_idx; i++)
                 {
                  append_double(BDArrayExt, d_price +  i * StepBD);
                 }

               double e_upper_boundary_cd = d_price + (c_price - d_price) * max_width_e * 0.01;
               double e_lower_boundary_cd = d_price + (c_price - d_price) * min_width_e * 0.01;

               for(int e_idx = e_min_idx; e_idx > e_max_idx; e_idx--)
                 {

                  bool _continue_e = false;
                  double current_e_low = iLow(_symbol, _period, e_idx);
                  double e_price = iHigh(_symbol, _period, e_idx);
                  int bars_c_e = c_idx - e_idx;

                  for(int i = 0; i < d_idx - e_idx; i++)
                    {
                     double tmp_low = iLow(_symbol, _period, d_idx - i - 1);
                     double tmp_bd_val = BDArrayExt[i];
                     if(tmp_low < tmp_bd_val)
                       {
                        _continue_e = true;
                        break;
                       }
                    }

                  if(_continue_e)
                     continue;

                  if(e_price > e_upper_boundary_cd || e_price < e_lower_boundary_cd)
                    {
                     continue;
                    }

                  double StepCE = (e_price - c_price) / bars_c_e;
                  double CEArray[];
                  double New_CEArray[];
                  for(int j2 = 1; j2 <= bars_c_e; j2++)
                    {
                     int idx = (int)((b_start_idx - b_idx) / every_increasing_of_value);
                     double real_ce_val = (c_price + j2 * StepCE);
                     append_double(CEArray, real_ce_val);
                     append_double(New_CEArray, real_ce_val + real_ce_val * idx * width_increasing_percentage_a_e * 0.01);
                    }

                  for(int i = 0; i < bars_c_e; i++)
                    {
                     double new_ce_array_val = New_CEArray[i];
                     double temp_e_val = iHigh(_symbol, _period, c_idx - i - 1);
                     if(temp_e_val > new_ce_array_val)
                       {
                        _continue_e = true;
                        break;
                       }
                    }

                  if(_continue_e)
                     continue;

                  my_wave_struct.e_idx = e_idx;
                  my_wave_struct.e_price = e_price;

                  if(pattern_type == X_A_B_C_D_E)
                    {
                     if(!divergence_filter(c_idx, d_idx, e_idx, 1))
                        continue;

                     if(!tick_speed_filter(x_idx, e_idx))
                        continue;

                     if(draw_lines)
                        draw_pattern(X_A_B_C_D_E, my_wave_struct);

                     if(draw_labels)
                       {
                        draw_label("X", "X", x_idx, -1);
                        draw_label("A", "A", a_idx, 1);
                        draw_label("B", "B", b_idx, -1);
                        draw_label("C", "C", c_idx, 1);
                        draw_label("D", "D", d_idx, -1);
                        draw_label("E", "E", e_idx, 1);
                       }

                     phase_two(X_A_B_C_D_E, my_wave_struct);
                     continue;
                    }

                  // Calculating F Point
                  int f_min_idx = d_idx - (int)(bars_x_b * min_d_to_f_btw_x_b * 0.01);
                  int f_max_idx = d_idx - (int)(bars_x_b * max_d_to_f_btw_x_b * 0.01);
                  if(f_min_idx >= e_idx)
                     f_min_idx = e_idx - 1;

                  double CEArrayExt[];
                  for(int i2 = 1; i2 <= e_idx - f_max_idx; i2++)
                    {
                     append_double(CEArrayExt, e_price + i2 * StepCE);
                    }

                  double f_upper_boundary_xb = x_price + (b_price - x_price) * max_width_f_xb * 0.01;
                  double f_lower_boundary_xb = x_price + (b_price - x_price) * min_width_f_xb * 0.01;

                  double f_upper_boundary_de = d_price + (e_price - d_price) * max_width_f_de * 0.01;
                  double f_lower_boundary_de = d_price + (e_price - d_price) * min_width_f_de * 0.01;

                  for(int f_idx = f_min_idx; f_idx > f_max_idx; f_idx--)
                    {
                     bool _continue_f = false;
                     double current_f_low = iHigh(_symbol, _period, f_idx);
                     double f_price_val = iLow(_symbol, _period, f_idx);
                     int bars_d_f = d_idx - f_idx;

                     if(bars_d_f <= 0)
                        continue;

                     for(int i2 = 0; i2 < e_idx - f_idx; i2++)
                       {
                        double tmp_high = iHigh(_symbol, _period, e_idx - i2 - 1);
                        double tmp_ce_val = CEArrayExt[i2];
                        if(tmp_high > tmp_ce_val)
                          {
                           _continue_f = true;
                           break;
                          }
                       }

                     if(_continue_f)
                        continue;

                     if(f_price_val > f_upper_boundary_xb || f_price_val < f_lower_boundary_xb)
                       {
                        continue;
                       }

                     if(f_price_val > f_upper_boundary_de || f_price_val < f_lower_boundary_de)
                       {
                        continue;
                       }

                     double StepDF = (f_price_val - d_price) / bars_d_f;
                     double DFArray[];
                     double New_DFArray[];
                     for(int j3 = 1; j3 <= bars_d_f; j3++)
                       {
                        int idx2 = (int)((b_start_idx - b_idx) / every_increasing_of_value);
                        double real_df_val = (d_price + j3 * StepDF);
                        append_double(DFArray, real_df_val);
                        append_double(New_DFArray, real_df_val - real_df_val * idx2 * width_increasing_percentage_a_e * 0.01);
                       }

                     for(int i2 = 0; i2 < bars_d_f; i2++)
                       {
                        double new_df_array_val = New_DFArray[i2];
                        double temp_f_val = iLow(_symbol, _period, d_idx - i2 - 1);
                        if(temp_f_val < new_df_array_val)
                          {
                           _continue_f = true;
                           break;
                          }
                       }

                     if(_continue_f)
                        continue;

                     my_wave_struct.f_idx = f_idx;
                     my_wave_struct.f_price = f_price_val;

                     if(pattern_type == X_A_B_C_D_E_F)
                       {
                        if(!divergence_filter(d_idx, e_idx, f_idx, -1))
                           continue;

                        if(!tick_speed_filter(x_idx, f_idx))
                           continue;

                        if(draw_lines)
                           draw_pattern(X_A_B_C_D_E_F, my_wave_struct);

                        if(draw_labels)
                          {
                           draw_label("X", "X", x_idx, -1);
                           draw_label("A", "A", a_idx, 1);
                           draw_label("B", "B", b_idx, -1);
                           draw_label("C", "C", c_idx, 1);
                           draw_label("D", "D", d_idx, -1);
                           draw_label("E", "E", e_idx, 1);
                           draw_label("F", "F", f_idx, -1);
                          }

                        phase_two(X_A_B_C_D_E_F, my_wave_struct);
                        continue;
                       }
                    }
                 }
              }
           }

         if(_continue_b)
            continue;
        }
     }

   draw_progress("Finished.", clrAqua);
  }


//+------------------------------------------------------------------+
//| PHASE ONE BEARISH - Pattern Detection                            |
//+------------------------------------------------------------------+
void phase_one_bearish()
  {
   draw_progress("Updating ...", clrGray);

   string _symbol = _Symbol;
   ENUM_TIMEFRAMES _period = _Period;

   int x_bars = Bars(_symbol, _period) - 1;

   for(int x_idx = x_bars ; x_idx > 0; x_idx--)
     {
      double x_price = iHigh(_symbol, _period, x_idx);
      if(x_price == 0)
         continue;

      double dynamic_max_width_percentage;
      double dynamic_min_width_percentage;

      int b_start_idx = x_idx - 1 - b_min;

      my_wave_struct.x_idx = x_idx;
      my_wave_struct.x_price = x_price;

      for(int b_idx = b_start_idx; b_idx > x_idx - b_max; b_idx--)
        {
         double b_price = iHigh(_symbol, _period, b_idx);
         int bars_x_b = x_idx - b_idx;
         double StepXB;
         double XBArray[];
         bool _continue_b = false;

         StepXB = (b_price - x_price) / bars_x_b;
         for(int j = 1; j <= bars_x_b; j++)
           {
            append_double(XBArray, (x_price + j * StepXB));
           }

         int bars_p_x = int(px_lenght_percentage * 0.01 * bars_x_b);

         if(x_bars - x_idx < bars_p_x)
            break;

         int p_idx = x_idx + bars_p_x;
         double p_price = x_price - (bars_p_x * StepXB);

         double px_array[];
         for(int px_array_idx = 0; px_array_idx < bars_x_b; px_array_idx++)
           {
            append_double(px_array, p_price + px_array_idx * StepXB);
           }

         for(int px_idx = 0 ; px_idx < bars_p_x; px_idx++)
           {
            int real_p_idx = x_idx + 1 + px_idx;
            double p_bar_low = iHigh(_symbol, _period, real_p_idx);
            double p_array_value = px_array[bars_p_x - 1 - px_idx];

            if(p_bar_low > p_array_value)
              {
               _continue_b = true;
               break;
              }
           }

         if(_continue_b)
            continue;

         for(int xb_idx = 0 ; xb_idx < bars_x_b; xb_idx++)
           {
            int real_b_idx = x_idx - xb_idx - 1 ;
            double b_bar_low = iHigh(_symbol, _period, real_b_idx);
            double b_array_value = XBArray[xb_idx];

            if(b_bar_low > b_array_value)
              {
               _continue_b = true;
               break;
              }
           }

         if(_continue_b)
            continue;

         my_wave_struct.b_idx = b_idx;
         my_wave_struct.b_price = b_price;

         my_wave_struct.p_idx = p_idx;
         my_wave_struct.p_price = p_price;

         // Calculation A Point
         double ab_diff_array[];
         for(int ab_idx = 0; ab_idx < bars_x_b; ab_idx++)
           {
            double ab_diff =  XBArray[ab_idx] - iLow(_symbol, _period, x_idx - ab_idx);
            append_double(ab_diff_array,  ab_diff);
           }

         int a_idx =  x_idx - ArrayMaximum(ab_diff_array);
         double a_price = iLow(_symbol, _period, a_idx);

         double max_val = x_price - (x_price - a_price) * x_to_a_b_max * 0.01;
         double min_val = x_price - (x_price - a_price) * x_to_a_b_min * 0.01;

         if(b_price < max_val || b_price > min_val)
            continue;

         int _tmp_a_idx = a_idx;
         if(b_price < x_price)
           {
            for(int high_a = a_idx; high_a > b_idx; high_a--)
              {
               double high_a_price = iLow(_symbol, _period, high_a);
               if(high_a_price < a_price)
                 {
                  _tmp_a_idx = high_a;
                  a_price = high_a_price;
                 }
              }
           }
         else
           {
            for(int high_a = x_idx ; high_a >= a_idx; high_a--)
              {
               double high_a_price = iLow(_symbol, _period, high_a);
               if(high_a_price < a_price)
                 {
                  _tmp_a_idx = high_a;
                  a_price = high_a_price;
                 }
              }
           }
         a_idx = _tmp_a_idx;

         int dynamic_candles_count = b_start_idx - b_idx;
         double increasing_width_value = ((int)(dynamic_candles_count / every_increasing_of_value) + 1) * width_increasing_percentage_x_to_b;
         dynamic_max_width_percentage = max_width_percentage + increasing_width_value;
         dynamic_min_width_percentage = min_width_percentage + increasing_width_value;

         double z = XBArray[x_idx - a_idx];
         double a_upper_boundary = z - (z * dynamic_max_width_percentage * 0.01);
         double a_lower_boundary = z - (z * dynamic_min_width_percentage * 0.01) ;
         if(a_price < a_upper_boundary || a_price > a_lower_boundary)
            continue;

         my_wave_struct.a_idx = a_idx;
         my_wave_struct.a_price = a_price;

         if(pattern_type == X_A_B)
           {
            if(!divergence_filter(x_idx, a_idx, b_idx, 1))
               continue;

            if(!tick_speed_filter(x_idx, b_idx))
               continue;

            if(draw_lines)
               draw_pattern(X_A_B, my_wave_struct);

            if(draw_labels)
              {
               draw_label("X", "X", x_idx, 1);
               draw_label("A", "A", a_idx, -1);
               draw_label("B", "B", b_idx, 1);
              }

            phase_two_bearish(X_A_B, my_wave_struct);
            continue;
           }

         // Calculating C Point
         int c_min_idx = a_idx - (int)(bars_x_b * min_a_to_c_btw_x_b * 0.01);
         int c_max_idx = a_idx - (int)(bars_x_b * max_a_to_c_btw_x_b * 0.01);
         if(c_min_idx >= b_idx)
            c_min_idx = b_idx - 1;

         double BCArray[];
         for(int bc_idx = 1; bc_idx <= b_idx - c_max_idx; bc_idx++)
           {
            append_double(BCArray, b_price +  bc_idx * StepXB);
           }

         double c_upper_boundary = b_price - (b_price - a_price) * max_width_c * 0.01;
         double c_lower_boundary = b_price - (b_price - a_price) * min_width_c * 0.01;

         for(int c_idx = c_min_idx; c_idx > c_max_idx; c_idx--)
           {
            bool _continue_c = false;
            double current_c_low = iHigh(_symbol, _period, c_idx);
            double c_price = iLow(_symbol, _period, c_idx);
            int bars_a_c = a_idx - c_idx;

            for(int i = 0; i < b_idx - c_idx; i++)
              {
               double tmp_low = iHigh(_symbol, _period, b_idx - i - 1);
               double tmp_bc_val = BCArray[i];
               if(tmp_low > tmp_bc_val)
                 {
                  _continue_c = true;
                  break;
                 }
              }

            if(_continue_c)
               continue;

            if(c_price < c_upper_boundary || c_price > c_lower_boundary)
              {
               continue;
              }

            double StepAC = (c_price - a_price) / bars_a_c;
            double ACArray[];
            double New_ACArray[];
            for(int j = 1; j <= bars_a_c; j++)
              {
               int idx = (int)((b_start_idx - b_idx) / every_increasing_of_value);
               double real_ac_val = (a_price + j * StepAC);
               append_double(ACArray, real_ac_val);
               append_double(New_ACArray, real_ac_val - real_ac_val * idx * width_increasing_percentage_a_e * 0.01);
              }

            for(int i = 0; i < bars_a_c; i++)
              {
               double new_ac_array_val = New_ACArray[i];
               double temp_c_val = iLow(_symbol, _period, a_idx - i - 1);
               if(temp_c_val < new_ac_array_val)
                 {
                  _continue_c = true;
                  break;
                 }
              }

            if(_continue_c)
               continue;

            my_wave_struct.c_idx = c_idx;
            my_wave_struct.c_price = c_price;

            if(pattern_type == X_A_B_C)
              {
               if(!divergence_filter(a_idx, b_idx, c_idx, -1))
                  continue;

               if(!tick_speed_filter(x_idx, c_idx))
                  continue;

               if(draw_lines)
                  draw_pattern(X_A_B_C, my_wave_struct);

               if(draw_labels)
                 {
                  draw_label("X", "X", x_idx, 1);
                  draw_label("A", "A", a_idx, -1);
                  draw_label("B", "B", b_idx, 1);
                  draw_label("C", "C", c_idx, -1);
                 }

               phase_two_bearish(X_A_B_C, my_wave_struct);
               continue;
              }

            // Calculating D Point
            int d_min_idx = b_idx - (int)(bars_x_b * min_b_to_d_btw_x_b * 0.01);
            int d_max_idx = b_idx - (int)(bars_x_b * max_b_to_d_btw_x_b * 0.01);
            if(d_min_idx >= c_idx)
               d_min_idx = c_idx - 1;

            double ACArrayExt[];
            for(int i = 1; i <= b_idx - d_max_idx; i++)
              {
               append_double(ACArrayExt, c_price +  i * StepAC);
              }

            double d_upper_boundary_bc = b_price - (b_price - c_price) * max_width_d_bc * 0.01;
            double d_lower_boundary_bc = b_price - (b_price - c_price) * min_width_d_bc * 0.01;

            double d_upper_boundary_xa = x_price - (x_price - a_price) * max_width_d_xa * 0.01;
            double d_lower_boundary_xa = x_price - (x_price - a_price) * min_width_d_xa * 0.01;

            for(int d_idx = d_min_idx; d_idx > d_max_idx; d_idx--)
              {
               bool _continue_d = false;
               double current_d_low = iHigh(_symbol, _period, d_idx);
               double d_price = iHigh(_symbol, _period, d_idx);
               int bars_b_d = b_idx - d_idx;

               for(int i = 0; i < c_idx - d_idx; i++)
                 {
                  double tmp_high = iLow(_symbol, _period, c_idx - i - 1);
                  double tmp_ac_val = ACArrayExt[i];
                  if(tmp_high < tmp_ac_val)
                    {
                     _continue_d = true;
                     break;
                    }
                 }

               if(_continue_d)
                  continue;

               if(d_price < d_upper_boundary_bc || d_price > d_lower_boundary_bc)
                 {
                  continue;
                 }

               if(d_price < d_upper_boundary_xa || d_price > d_lower_boundary_xa)
                 {
                  continue;
                 }

               double StepBD = (d_price - b_price) / bars_b_d;
               double BDArray[];
               double New_BDArray[];
               for(int j = 1; j <= bars_b_d; j++)
                 {
                  int idx = (int)((b_start_idx - b_idx) / every_increasing_of_value);
                  double real_bd_val = (b_price + j * StepBD);
                  append_double(BDArray, real_bd_val);
                  append_double(New_BDArray, real_bd_val + real_bd_val * idx * width_increasing_percentage_a_e * 0.01);
                 }

               for(int i = 0; i < bars_b_d; i++)
                 {
                  double new_bd_array_val = New_BDArray[i];
                  double temp_d_val = iHigh(_symbol, _period, b_idx - i - 1);
                  if(temp_d_val > new_bd_array_val)
                    {
                     _continue_d = true;
                     break;
                    }
                 }

               if(_continue_d)
                  continue;

               my_wave_struct.d_idx = d_idx;
               my_wave_struct.d_price = d_price;

               if(pattern_type == X_A_B_C_D)
                 {
                  if(!divergence_filter(b_idx, c_idx, d_idx, 1))
                     continue;

                  if(!tick_speed_filter(x_idx, d_idx))
                     continue;

                  if(draw_lines)
                     draw_pattern(X_A_B_C_D, my_wave_struct);

                  if(draw_labels)
                    {
                     draw_label("X", "X", x_idx, 1);
                     draw_label("A", "A", a_idx, -1);
                     draw_label("B", "B", b_idx, 1);
                     draw_label("C", "C", c_idx, -1);
                     draw_label("D", "D", d_idx, 1);
                    }

                  phase_two_bearish(X_A_B_C_D, my_wave_struct);
                  continue;
                 }

               // Calculating E Point
               int e_min_idx = c_idx - (int)(bars_x_b * min_c_to_e_btw_x_b * 0.01);
               int e_max_idx = c_idx - (int)(bars_x_b * max_c_to_e_btw_x_b * 0.01);
               if(e_min_idx >= d_idx)
                  e_min_idx = d_idx - 1;

               double BDArrayExt[];
               for(int i = 1; i <= d_idx - e_max_idx; i++)
                 {
                  append_double(BDArrayExt, d_price +  i * StepBD);
                 }

               double e_upper_boundary_cd = d_price - (d_price - c_price) * max_width_e * 0.01;
               double e_lower_boundary_cd = d_price - (d_price - c_price) * min_width_e * 0.01;

               for(int e_idx = e_min_idx; e_idx > e_max_idx; e_idx--)
                 {
                  bool _continue_e = false;
                  double current_e_low = iHigh(_symbol, _period, e_idx);
                  double e_price = iLow(_symbol, _period, e_idx);
                  int bars_c_e = c_idx - e_idx;

                  for(int i = 0; i < d_idx - e_idx; i++)
                    {
                     double tmp_low = iHigh(_symbol, _period, d_idx - i - 1);
                     double tmp_bd_val = BDArrayExt[i];
                     if(tmp_low > tmp_bd_val)
                       {
                        _continue_e = true;
                        break;
                       }
                    }

                  if(_continue_e)
                     continue;

                  if(e_price < e_upper_boundary_cd || e_price > e_lower_boundary_cd)
                    {
                     continue;
                    }

                  double StepCE = (e_price - c_price) / bars_c_e;
                  double CEArray[];
                  double New_CEArray[];
                  for(int j2 = 1; j2 <= bars_c_e; j2++)
                    {
                     int idx = (int)((b_start_idx - b_idx) / every_increasing_of_value);
                     double real_ce_val = (c_price + j2 * StepCE);
                     append_double(CEArray, real_ce_val);
                     append_double(New_CEArray, real_ce_val - real_ce_val * idx * width_increasing_percentage_a_e * 0.01);
                    }

                  for(int i = 0; i < bars_c_e; i++)
                    {
                     double new_ce_array_val = New_CEArray[i];
                     double temp_e_val = iLow(_symbol, _period, c_idx - i - 1);
                     if(temp_e_val < new_ce_array_val)
                       {
                        _continue_e = true;
                        break;
                       }
                    }

                  if(_continue_e)
                     continue;

                  my_wave_struct.e_idx = e_idx;
                  my_wave_struct.e_price = e_price;

                  if(pattern_type == X_A_B_C_D_E)
                    {
                     if(!divergence_filter(c_idx, d_idx, e_idx, -1))
                        continue;

                     if(!tick_speed_filter(x_idx, e_idx))
                        continue;

                     if(draw_lines)
                        draw_pattern(X_A_B_C_D_E, my_wave_struct);

                     if(draw_labels)
                       {
                        draw_label("X", "X", x_idx, 1);
                        draw_label("A", "A", a_idx, -1);
                        draw_label("B", "B", b_idx, 1);
                        draw_label("C", "C", c_idx, -1);
                        draw_label("D", "D", d_idx, 1);
                        draw_label("E", "E", e_idx, -1);
                       }

                     phase_two_bearish(X_A_B_C_D_E, my_wave_struct);
                     continue;
                    }

                  // Calculating F Point
                  int f_min_idx = d_idx - (int)(bars_x_b * min_d_to_f_btw_x_b * 0.01);
                  int f_max_idx = d_idx - (int)(bars_x_b * max_d_to_f_btw_x_b * 0.01);
                  if(f_min_idx >= e_idx)
                     f_min_idx = e_idx - 1;

                  double CEArrayExt[];
                  for(int i2 = 1; i2 <= e_idx - f_max_idx; i2++)
                    {
                     append_double(CEArrayExt, e_price + i2 * StepCE);
                    }

                  double f_upper_boundary_xb = x_price - (x_price - b_price) * max_width_f_xb * 0.01;
                  double f_lower_boundary_xb = x_price - (x_price - b_price) * min_width_f_xb * 0.01;

                  double f_upper_boundary_de = d_price - (d_price - e_price) * max_width_f_de * 0.01;
                  double f_lower_boundary_de = d_price - (d_price - e_price) * min_width_f_de * 0.01;

                  for(int f_idx = f_min_idx; f_idx > f_max_idx; f_idx--)
                    {
                     bool _continue_f = false;
                     double current_f_high = iLow(_symbol, _period, f_idx);
                     double f_price_val = iHigh(_symbol, _period, f_idx);
                     int bars_d_f = d_idx - f_idx;

                     if(bars_d_f <= 0)
                        continue;

                     for(int i2 = 0; i2 < e_idx - f_idx; i2++)
                       {
                        double tmp_low = iLow(_symbol, _period, e_idx - i2 - 1);
                        double tmp_ce_val = CEArrayExt[i2];
                        if(tmp_low < tmp_ce_val)
                          {
                           _continue_f = true;
                           break;
                          }
                       }

                     if(_continue_f)
                        continue;

                     if(f_price_val < f_upper_boundary_xb || f_price_val > f_lower_boundary_xb)
                       {
                        continue;
                       }

                     if(f_price_val < f_upper_boundary_de || f_price_val > f_lower_boundary_de)
                       {
                        continue;
                       }

                     double StepDF = (f_price_val - d_price) / bars_d_f;
                     double DFArray[];
                     double New_DFArray[];
                     for(int j3 = 1; j3 <= bars_d_f; j3++)
                       {
                        int idx2 = (int)((b_start_idx - b_idx) / every_increasing_of_value);
                        double real_df_val = (d_price + j3 * StepDF);
                        append_double(DFArray, real_df_val);
                        append_double(New_DFArray, real_df_val + real_df_val * idx2 * width_increasing_percentage_a_e * 0.01);
                       }

                     for(int i2 = 0; i2 < bars_d_f; i2++)
                       {
                        double new_df_array_val = New_DFArray[i2];
                        double temp_f_val = iHigh(_symbol, _period, d_idx - i2 - 1);
                        if(temp_f_val > new_df_array_val)
                          {
                           _continue_f = true;
                           break;
                          }
                       }

                     if(_continue_f)
                        continue;

                     my_wave_struct.f_idx = f_idx;
                     my_wave_struct.f_price = f_price_val;

                     if(pattern_type == X_A_B_C_D_E_F)
                       {
                        if(!divergence_filter(d_idx, e_idx, f_idx, 1))
                           continue;

                        if(!tick_speed_filter(x_idx, f_idx))
                           continue;

                        if(draw_lines)
                           draw_pattern(X_A_B_C_D_E_F, my_wave_struct);

                        if(draw_labels)
                          {
                           draw_label("X", "X", x_idx, 1);
                           draw_label("A", "A", a_idx, -1);
                           draw_label("B", "B", b_idx, 1);
                           draw_label("C", "C", c_idx, -1);
                           draw_label("D", "D", d_idx, 1);
                           draw_label("E", "E", e_idx, -1);
                           draw_label("F", "F", f_idx, 1);
                          }

                        phase_two_bearish(X_A_B_C_D_E_F, my_wave_struct);
                        continue;
                       }
                    }
                 }
              }
           }

         if(_continue_b)
            continue;
        }
     }

   draw_progress("Finished.", clrAqua);
  }


//+------------------------------------------------------------------+
//| Draw pattern lines                                               |
//+------------------------------------------------------------------+
void draw_pattern(pattern_type_enum _type, wave_struct& _wave_struct)
  {
   double  p_price = _wave_struct.p_price;
   int p_idx = _wave_struct.p_idx;

   double x_price = _wave_struct.x_price;
   int x_idx = _wave_struct.x_idx;

   double a_price = _wave_struct.a_price;
   int a_idx = _wave_struct.a_idx;

   double b_price = _wave_struct.b_price;
   int b_idx = _wave_struct.b_idx;

   double c_price = _wave_struct.c_price;
   int c_idx = _wave_struct.c_idx;

   double d_price = _wave_struct.d_price;
   int d_idx = _wave_struct.d_idx;

   double e_price = _wave_struct.e_price;
   int e_idx = _wave_struct.e_idx;

   double f_price = _wave_struct.f_price;
   int f_idx = _wave_struct.f_idx;

   draw_line("px", x_idx, p_idx, p_price, x_idx, x_price, px_color);

   switch(_type)
     {
      case X_A_B:
         draw_line("xa", x_idx, x_idx, x_price, a_idx, a_price, xa_color);
         draw_line("ab", x_idx, a_idx, a_price, b_idx, b_price, ab_color);
         break;

      case X_A_B_C:
         draw_line("xa", x_idx, x_idx, x_price, a_idx, a_price, xa_color);
         draw_line("ab", x_idx, a_idx, a_price, b_idx, b_price, ab_color);
         draw_line("bc", x_idx, b_idx, b_price, c_idx, c_price, bc_color);
         break;

      case X_A_B_C_D:
         draw_line("xa", x_idx, x_idx, x_price, a_idx, a_price, xa_color);
         draw_line("ab", x_idx, a_idx, a_price, b_idx, b_price, ab_color);
         draw_line("bc", x_idx, b_idx, b_price, c_idx, c_price, bc_color);
         draw_line("cd", x_idx, c_idx, c_price, d_idx, d_price, cd_color);
         break;

      case X_A_B_C_D_E:
         draw_line("xa", x_idx, x_idx, x_price, a_idx, a_price, xa_color);
         draw_line("ab", x_idx, a_idx, a_price, b_idx, b_price, ab_color);
         draw_line("bc", x_idx, b_idx, b_price, c_idx, c_price, bc_color);
         draw_line("cd", x_idx, c_idx, c_price, d_idx, d_price, cd_color);
         draw_line("de", x_idx, d_idx, d_price, e_idx, e_price, de_color);
         break;

      case X_A_B_C_D_E_F:
         draw_line("xa", x_idx, x_idx, x_price, a_idx, a_price, xa_color);
         draw_line("ab", x_idx, a_idx, a_price, b_idx, b_price, ab_color);
         draw_line("bc", x_idx, b_idx, b_price, c_idx, c_price, bc_color);
         draw_line("cd", x_idx, c_idx, c_price, d_idx, d_price, cd_color);
         draw_line("de", x_idx, d_idx, d_price, e_idx, e_price, de_color);
         draw_line("ef", x_idx, e_idx, e_price, f_idx, f_price, ef_color);
         break;

      default:
         return;
     }
   ChartRedraw();
   return;
  }


//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
void append_double(double& myarray[], double value)
  {
   ArrayResize(myarray, ArraySize(myarray) + 1);
   myarray[ArraySize(myarray) - 1] = value;
  }

void append_int(int& myarray[], int value)
  {
   ArrayResize(myarray, ArraySize(myarray) + 1);
   myarray[ArraySize(myarray) - 1] = value;
  }

void draw_line(string _name, int x_idx, int idx1, double price1, int idx2, double price2, color _color)
  {
   string salt = (string)MathRand() + (string)MathRand() + (string)MathRand();
   string _myname = Prefix + _name + (string)x_idx + salt;

   datetime time2;
   if(idx2 >= 0)
      time2 = iTime(_Symbol, _Period, idx2) ;
   else
      time2 = iTime(_Symbol, _Period, 0) + (idx2 * -1) * PeriodSeconds();

   ObjectCreate(0, _myname, OBJ_TREND, 0, iTime(_Symbol, _Period, idx1), price1, time2, price2);
   ObjectSetInteger(0, _myname, OBJPROP_COLOR, _color);
   ObjectSetInteger(0, _myname, OBJPROP_WIDTH, 2);
  }

void draw_arrow(string _name, int idx1, double price1)
  {
   string salt = (string)MathRand() + (string)MathRand() + (string)MathRand();
   string _myname = Prefix + _name + salt;
   ObjectCreate(0, _myname, _name == "buy" ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, iTime(_Symbol, _Period, idx1), price1);
   ObjectSetInteger(0, _myname, OBJPROP_COLOR, _name == "buy" ? arrow_buy_color : arrow_sell_color);
   ObjectSetInteger(0, _myname, OBJPROP_WIDTH, arrow_size);
   if(_name == "sell")
      ObjectSetInteger(0, _myname, OBJPROP_ANCHOR, ANCHOR_LOWER);
  }

void draw_label(string _name, string _txt, int idx1, int _vert_pos)
  {
   double price1 = _vert_pos == 1 ? mrate[idx1].high : mrate[idx1].low;
   string salt = (string)MathRand();
   string _myname = Prefix + _name + salt;
   ObjectCreate(0, _myname, OBJ_TEXT, 0, iTime(_Symbol, _Period, idx1), price1);
   ObjectSetString(0, _myname, OBJPROP_TEXT, _txt);
   ObjectSetInteger(0, _myname, OBJPROP_FONTSIZE, label_font_size);
   ObjectSetInteger(0, _myname, OBJPROP_COLOR, label_font_color);
   if(_vert_pos == 1)
      ObjectSetInteger(0, _myname, OBJPROP_ANCHOR, ANCHOR_LOWER);
  }

void draw_progress(string _text, color _clr)
  {
   string _status = Prefix + "status";
   ObjectCreate(0, _status, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, _status, OBJPROP_TEXT, _text);
   ObjectSetInteger(0, _status, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, _status, OBJPROP_YDISTANCE, 30);
   ObjectSetInteger(0, _status, OBJPROP_COLOR, _clr);
   ChartRedraw();
  }

void update_rates()
  {
   ArraySetAsSeries(mrate,true);
   if(CopyRates(_Symbol,_Period,0, Bars(_Symbol, _Period),mrate) < 0)
      return;
  }

bool tick_speed_filter(int idx1, int idx2)
  {
   int seconds1 = int(iTime(_Symbol, _Period, idx2) - iTime(_Symbol, _Period, idx1));
   int bars1 = idx1 - idx2;

   if(seconds1 / bars1 < tick_min_speed)
      return true;

   return false;
  }

bool divergence_filter(int idx1, int idx2, int idx3, int _direction)
  {
   double idx1_high = iHigh(_Symbol, _Period, idx1);
   double idx2_high = iHigh(_Symbol, _Period, idx2);
   double idx3_high = iHigh(_Symbol, _Period, idx3);

   double idx1_low = iLow(_Symbol, _Period, idx1);
   double idx2_low = iLow(_Symbol, _Period, idx2);
   double idx3_low = iLow(_Symbol, _Period, idx3);

   int seconds1 = int(iTime(_Symbol, _Period, idx2) - iTime(_Symbol, _Period, idx1));
   int seconds2 = int(iTime(_Symbol, _Period, idx3) - iTime(_Symbol, _Period, idx2));

   double leg1_up_direction = idx1_high - idx2_low;
   double leg2_up_direction = idx3_high - idx2_low;

   double leg1_down_direction = idx2_high - idx1_low;
   double leg2_down_direction = idx2_high - idx3_low;

   bool second_leg_is_bigger = false;
   if(_direction == 1)
     {
      if(leg2_up_direction > leg1_up_direction)
         second_leg_is_bigger = true;
     }
   else
     {
      if(leg2_down_direction > leg1_down_direction)
         second_leg_is_bigger = true;
     }

   double vol1 = 0;
   double vol2 = 0;

   for(int i = idx1; i >= idx2; i--)
     {
      vol1 = vol1 + iVolume(_Symbol, _Period, i);
     }

   for(int i = idx2; i >= idx3; i--)
     {
      vol2 = vol2 + iVolume(_Symbol, _Period, i);
     }

   int bars1 = idx1 - idx2;
   int bars2 = idx2 - idx3;

   if(bars1 == 0 || bars2 == 0)
      return false;

   if(divergence_type == None_Divergence)
      return true;

   if(divergence_type == Time_Divergence)
     {
      if(
         (second_leg_is_bigger && (seconds2 / bars2) < (seconds1 / bars1))  ||
         (!second_leg_is_bigger && (seconds2 / bars2) > (seconds1 / bars1))
      )
         return true;
     }

   if(divergence_type == Volume_Divergence)
     {
      if(
         (second_leg_is_bigger && vol2 < vol1)  ||
         (!second_leg_is_bigger && vol2 > vol1)
      )
         return true;
     }

   if(divergence_type == Time_Volume_Divergence)
     {
      if(
         (second_leg_is_bigger && (vol2 / bars2) < (vol1 / bars1))  ||
         (!second_leg_is_bigger && (vol2 / bars2) > (vol1 / bars1))
      )
         return true;
     }

   return false;
  }
//+------------------------------------------------------------------+
