//+------------------------------------------------------------------+
//|                       GOLDEN LINE PXABCDEF CHANNELS V3.mq5       |
//|       Golden Line Algorithm from AbdullahProjSourceCode.mq5      |
//|                                                                  |
//+------------------------------------------------------------------+
//| KEY CONCEPTS:                                                    |
//+------------------------------------------------------------------+
//| 1. PATTERN DIRECTION (for user filtering):                       |
//|    - BULLISH: last_point < previous_point (e.g., C < B)          |
//|    - BEARISH: last_point > previous_point (e.g., C > B)          |
//|                                                                  |
//| 2. GOLDEN LINE TYPE (based on X vs A relationship):              |
//|    - UPTREND (X < A): X is LOW → Call golden_line_uptrend()     |
//|    - DOWNTREND (X > A): X is HIGH → Call golden_line_downtrend()|
//|                                                                  |
//| 3. GOLDEN LINE ALGORITHM (from AbdullahProjSourceCode.mq5):      |
//|    - SP = Previous-to-last point (B for XABC, C for XABCD)       |
//|    - Uses OPPOSITE price type from last point!                   |
//|      * Last is HIGH → use LOWs for calculation                   |
//|      * Last is LOW → use HIGHs for calculation                   |
//|                                                                  |
//| 4. SIGNAL TYPE (alternates with pattern):                        |
//|    UPTREND (X<A): XAB=BUY, XABC=SELL, XABCD=BUY, XABCDE=SELL    |
//|    DOWNTREND(X>A): XAB=SELL, XABC=BUY, XABCD=SELL, XABCDE=BUY  |
//|                                                                  |
//| 5. SLOPE VALIDATION based on X vs A relationship                 |
//| 6. CHANNEL SYSTEM: XB-channel and A-channel for CDEF points      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "3.00"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "===== Pattern Type ====="
enum pattern_type_enum {XAB=0, XABC=1, XABCD=2, XABCDE=3, XABCDEF=4};
input pattern_type_enum pattern_type = XABCD; // Pattern Type (3-7 points)

enum pattern_direction_enum {Bullish, Bearish, Both};
input pattern_direction_enum pattern_direction = Both; // Pattern Direction Filter

input group "===== Length Properties ====="
input int b_min = 20; // B Min length index from X
input int b_max = 100; // B Max length index from X
input int max_search_bars = 0; // Maximum bars to search back (0=all)
input double px_length_percentage = 10; // PX line % relative to XB

input double min_b_to_c_btw_x_b = 0; // Min BC length % relative to XB (from B)
input double max_b_to_c_btw_x_b = 100; // Max BC length % relative to XB (from B)
input double min_c_to_d_btw_x_b = 0; // Min CD length % relative to XB (from C)
input double max_c_to_d_btw_x_b = 100; // Max CD length % relative to XB (from C)
input double min_d_to_e_btw_x_b = 0; // Min DE length % relative to XB (from D)
input double max_d_to_e_btw_x_b = 100; // Max DE length % relative to XB (from D)
input double min_e_to_f_btw_x_b = 0; // Min EF length % relative to XB (from E)
input double max_e_to_f_btw_x_b = 100; // Max EF length % relative to XB (from E)

input group "===== Retracement Properties ====="
input double max_width_percentage = 100; // Max A retrace % from X
input double min_width_percentage = 0; // Min A retrace % from X
input double x_to_a_b_max = 100; // Max B retrace % from XA
input double x_to_a_b_min = -100; // Min B retrace % from XA

input group "===== Dynamic Height Properties ====="
input int every_increasing_of_value = 5; // Every candle count increase
input double width_increasing_percentage_x_to_b = 0; // Height increase % for XB
input double width_increasing_percentage_a_e = 0; // Max price buffer % from AC and BD and CE

input group "===== Validation ====="
input bool strict_xb_validation = false; // Strict XB validation (no breaks below/above XB line)
input bool only_draw_most_recent = true; // Only draw most recent pattern
input int min_bars_between_patterns = 10; // Minimum bars between patterns
input double slope_buffer_pct = 0.0; // Slope Buffer % (AC/BD/CE/DF only, XB=strict)

input group "===== Channel Type ====="
enum channel_type_enum {Parallel, Straight, Non_Parallel, All_Types};
input channel_type_enum channel_type = Parallel; // Channel Type

input group "===== Channel Width Settings ====="
input double xb_upper_width_pct = 0.5; // XB Slope Upper Channel Width %
input double xb_lower_width_pct = 0.5; // XB Slope Lower Channel Width %
input double a_upper_width_pct = 0.5; // A Slope Upper Channel Width %
input double a_lower_width_pct = 0.5; // A Slope Lower Channel Width %

input group "===== Channel Extension ====="
input int channel_extension_bars = 200; // Channel extension bars after last point

input group "===== Golden Line Settings ====="
input double f_percentage = 50; // Separator line height %
input int fg_increasing_percentage = 5; // Separator increment % per iteration
input double first_line_percentage = 4; // Initial slope line %
input double first_line_decrease_percentage = 0.01; // Slope decrease % per iteration
input double maxBelow_maxAbove_diff_percentage = 40; // M N equality tolerance %
input double mn_buffer_percent = 0; // MN buffer % (safety margin - moves line away from price)
input double mn_length_percent = 0; // Min MN segment length % (0=no minimum)
input int mn_extension_bars = 20; // Golden Line extension bars
input bool extension_break_close = false; // Use CLOSE for break detection (else HIGH/LOW)

input bool draw_golden_line = true; // Show Golden Line (MN)
input bool draw_fg_line = false; // Show FG Separator Line
input color golden_line_color = clrGold; // Golden Line Color

input group "===== Dynamic Last Point (Live Trading) ====="
input bool enable_dynamic_last_point = true; // Enable Dynamic Last Point Tracking
input color dynamic_last_point_color = clrWhite; // Dynamic Last Point Label Color
input int max_dynamic_iterations = 10; // Max iterations for dynamic last point
input color fg_line_color = clrKhaki; // FG Separator Line Color

input group "===== Visual Styles ====="
input color arrow_buy_color = clrViolet; // Buy Arrow Color
input color arrow_sell_color = clrRed; // Sell Arrow Color
input int arrow_size = 4; // Arrow Size

input bool draw_labels = true; // Show Labels
input int label_font_size = 11; // Label Size
input color label_font_color = clrRed; // Label Color

input bool draw_pattern_lines = true; // Show Pattern Lines
input bool draw_channel_lines = true; // Show Channel Lines

input color px_color = clrRed; // PX Color
input color xa_color = clrWhite; // XA Color
input color ab_color = clrWhite; // AB Color
input color bc_color = clrWhite; // BC Color
input color cd_color = clrWhite; // CD Color
input color de_color = clrWhite; // DE Color
input color ef_color = clrWhite; // EF Color
input color xb_channel_color = clrAqua; // XB Channel Color
input color a_channel_color = clrLime; // A Channel Color

input group "===== Filters ====="
enum divergence_type_enum {None_Divergence, Time_Divergence, Volume_Divergence, Time_Volume_Divergence};
input divergence_type_enum divergence_type = None_Divergence; // Divergence Filter Type
input int tick_min_speed = 500000; // TickChart min speed

string Prefix = "glv2_";

//+------------------------------------------------------------------+
//| Wave Structure                                                    |
//+------------------------------------------------------------------+
struct wave_struct {
   double p_price, x_price, a_price, b_price, c_price, d_price, e_price, f_price;
   int p_idx, x_idx, a_idx, b_idx, c_idx, d_idx, e_idx, f_idx;
   bool is_bullish;  // Determined by pattern: last_point < prev_point = bullish
   bool x_less_than_a;  // For slope validation rules
};

wave_struct g_wave = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,false,false};
channel_type_enum active_channel_type = Parallel;
MqlRates mrate[];

//+------------------------------------------------------------------+
//| Reset wave structure                                              |
//+------------------------------------------------------------------+
void reset_wave(wave_struct& ws) {
   ws.p_price=0; ws.x_price=0; ws.a_price=0; ws.b_price=0;
   ws.c_price=0; ws.d_price=0; ws.e_price=0; ws.f_price=0;
   ws.p_idx=0; ws.x_idx=0; ws.a_idx=0; ws.b_idx=0;
   ws.c_idx=0; ws.d_idx=0; ws.e_idx=0; ws.f_idx=0;
   ws.is_bullish=false; ws.x_less_than_a=false;
}

//+------------------------------------------------------------------+
//| Determine if next point should be HIGH or LOW                     |
//| README RULE: If prev > prev_prev → next is LOW                   |
//|              If prev < prev_prev → next is HIGH                  |
//+------------------------------------------------------------------+
bool next_point_is_low(double prev_price, double prev_prev_price) {
   return (prev_price > prev_prev_price);
}

//+------------------------------------------------------------------+
//| Determine pattern direction based on last two points              |
//| README RULE: BULLISH if last < previous, BEARISH if last > prev  |
//+------------------------------------------------------------------+
bool determine_pattern_bullish(double last_price, double prev_price) {
   return (last_price < prev_price);
}

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit() {
   Print("V2: Starting pattern search...");
   update_rates();
   find_all_patterns();
   ChartRedraw();
   Print("V2: Init complete. Objects: ", ObjectsTotal(0));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { ObjectsDeleteAll(0, Prefix); }
void OnTick() { }

//+------------------------------------------------------------------+
//| Update rates array                                                |
//+------------------------------------------------------------------+
void update_rates() {
   ArraySetAsSeries(mrate, true);
   CopyRates(_Symbol, _Period, 0, Bars(_Symbol, _Period), mrate);
}

//+------------------------------------------------------------------+
//| Find all patterns                                                 |
//+------------------------------------------------------------------+
void find_all_patterns() {
   int total_bars = Bars(_Symbol, _Period) - 1;
   int search_start = (max_search_bars > 0 && max_search_bars < total_bars) ? max_search_bars : total_bars;
   int patterns_found = 0;

   channel_type_enum types_to_run[];
   if(channel_type == All_Types) {
      ArrayResize(types_to_run, 3);
      types_to_run[0] = Parallel;
      types_to_run[1] = Straight;
      types_to_run[2] = Non_Parallel;
   } else {
      ArrayResize(types_to_run, 1);
      types_to_run[0] = channel_type;
   }

   for(int t = 0; t < ArraySize(types_to_run); t++) {
      active_channel_type = types_to_run[t];
      int last_drawn_idx = -9999;

      for(int x_idx = search_start; x_idx > b_max + 10; x_idx--) {
         reset_wave(g_wave);

         // Try both X as LOW and X as HIGH starting points
         if(try_find_pattern_from_x(x_idx, true, last_drawn_idx))  // X is LOW
            patterns_found++;
         if(try_find_pattern_from_x(x_idx, false, last_drawn_idx)) // X is HIGH
            patterns_found++;
      }
   }

   Print("V2: Found ", patterns_found, " patterns");
}

//+------------------------------------------------------------------+
//| Try to find pattern starting from X                               |
//| Now iterates through ALL valid B candidates until one works       |
//+------------------------------------------------------------------+
bool try_find_pattern_from_x(int x_idx, bool x_is_low, int& last_drawn_idx) {
   double x_price = x_is_low ? iLow(_Symbol, _Period, x_idx) : iHigh(_Symbol, _Period, x_idx);
   if(x_price == 0) return false;
   
   //=================================================================
   // STEP 1: Collect ALL valid B candidates (local extrema in range)
   // Instead of just picking the most extreme, try each candidate
   //=================================================================
   int b_start_idx = x_idx - 1 - b_min;  // Start searching from b_min bars after X
   int b_end_idx = MathMax(x_idx - b_max, 0);  // End at b_max bars from X
   
   // Collect B candidates that are local extrema
   int b_candidates[];
   double b_prices[];
   
   for(int i = b_start_idx; i > b_end_idx && i > 0; i--) {
      double curr_price = x_is_low ? iLow(_Symbol, _Period, i) : iHigh(_Symbol, _Period, i);
      double prev_price = x_is_low ? iLow(_Symbol, _Period, i+1) : iHigh(_Symbol, _Period, i+1);
      double next_price = x_is_low ? iLow(_Symbol, _Period, i-1) : iHigh(_Symbol, _Period, i-1);
      
      // Check if it's a local extremum
      bool is_local_extreme = x_is_low ? 
         (curr_price <= prev_price && curr_price <= next_price) :
         (curr_price >= prev_price && curr_price >= next_price);
      
      if(is_local_extreme) {
         int size = ArraySize(b_candidates);
         ArrayResize(b_candidates, size + 1);
         ArrayResize(b_prices, size + 1);
         b_candidates[size] = i;
         b_prices[size] = curr_price;
      }
   }
   
   if(ArraySize(b_candidates) == 0) return false;
   
   // Sort candidates by extremeness (most extreme first)
   for(int i = 0; i < ArraySize(b_candidates) - 1; i++) {
      for(int j = i + 1; j < ArraySize(b_candidates); j++) {
         bool should_swap = x_is_low ? 
            (b_prices[j] < b_prices[i]) : 
            (b_prices[j] > b_prices[i]);
         if(should_swap) {
            int tmp_idx = b_candidates[i];
            b_candidates[i] = b_candidates[j];
            b_candidates[j] = tmp_idx;
            double tmp_price = b_prices[i];
            b_prices[i] = b_prices[j];
            b_prices[j] = tmp_price;
         }
      }
   }
   
   //=================================================================
   // Try each B candidate until one forms a valid pattern
   //=================================================================
   for(int bc = 0; bc < ArraySize(b_candidates); bc++) {
      reset_wave(g_wave);
      g_wave.x_idx = x_idx;
      g_wave.x_price = x_price;
      
      int b_idx = b_candidates[bc];
      double b_price = b_prices[bc];
      
      int bars_x_b = x_idx - b_idx;
      if(bars_x_b <= 0) continue;
      
      // Try to build pattern with this B candidate
      if(try_build_pattern_with_b(x_idx, x_price, x_is_low, b_idx, b_price, bars_x_b, last_drawn_idx)) {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Try to build pattern with specific B point                        |
//| Uses cascading candidate iteration for C, D, E, F                 |
//+------------------------------------------------------------------+
bool try_build_pattern_with_b(int x_idx, double x_price, bool x_is_low, 
                               int b_idx, double b_price, int bars_x_b, int& last_drawn_idx) {
   
   // Calculate XB slope
   double xb_slope = (b_price - x_price) / bars_x_b;
   
   // Build XB array for deviation calculation
   double XBArray[];
   ArrayResize(XBArray, bars_x_b + 1);
   for(int j = 0; j <= bars_x_b; j++) {
      XBArray[j] = x_price + j * xb_slope;
   }
   
   //=================================================================
   // STEP 2: Find A point BETWEEN X and B (opposite type from X)
   //=================================================================
   double max_deviation = -DBL_MAX;
   int a_idx = -1;
   double a_price = 0;
   
   for(int i = x_idx - 1; i > b_idx; i--) {
      int offset = x_idx - i;
      if(offset >= ArraySize(XBArray)) continue;
      
      double xb_value = XBArray[offset];
      double deviation;
      double price;
      
      if(x_is_low) {
         price = iHigh(_Symbol, _Period, i);
         deviation = price - xb_value;
      } else {
         price = iLow(_Symbol, _Period, i);
         deviation = xb_value - price;
      }
      
      if(deviation > max_deviation) {
         max_deviation = deviation;
         a_idx = i;
         a_price = price;
      }
   }
   if(a_idx == -1 || max_deviation <= 0) return false;
   if(a_idx >= x_idx || a_idx <= b_idx) return false;
   
   g_wave.a_idx = a_idx;
   g_wave.a_price = a_price;
   g_wave.x_less_than_a = (x_price < a_price);
   g_wave.b_idx = b_idx;
   g_wave.b_price = b_price;
   
   // Validate B retracement relative to XA
   double xb_retrace = (b_price - x_price) / (a_price - x_price) * 100;
   if(xb_retrace < x_to_a_b_min || xb_retrace > x_to_a_b_max) return false;

   // Validate A retracement (deviation from XB line within allowed % range)
   int a_offset = x_idx - a_idx;
   if(a_offset < 0 || a_offset >= ArraySize(XBArray)) return false;
   double z = XBArray[a_offset];  // XB line value at A's bar position

   int b_start_idx_local = x_idx - 1 - b_min;
   int dynamic_candles_count = b_start_idx_local - b_idx;
   if(dynamic_candles_count < 0) dynamic_candles_count = 0;
   double increasing_width_value = ((int)(dynamic_candles_count / every_increasing_of_value) + 1) * width_increasing_percentage_x_to_b;
   double dynamic_max_pct = max_width_percentage + increasing_width_value;
   double dynamic_min_pct = min_width_percentage + increasing_width_value;

   if(x_is_low) {
      // X < A (uptrend): A is HIGH, must be above XB line within range
      double a_upper = z + z * dynamic_max_pct * 0.01;
      double a_lower = z + z * dynamic_min_pct * 0.01;
      if(a_price > a_upper || a_price < a_lower) return false;
   } else {
      // X > A (downtrend): A is LOW, must be below XB line within range
      double a_upper = z - z * dynamic_max_pct * 0.01;
      double a_lower = z - z * dynamic_min_pct * 0.01;
      if(a_price < a_upper || a_price > a_lower) return false;
   }

   // STEP 2b: Secondary scan — find most extreme candle between A and B
   // Max deviation from slope doesn't guarantee most extreme price due to slope steepness
   // X<A: look for highest HIGH between A and B
   // X>A: look for lowest LOW between A and B
   for(int i = a_idx - 1; i > b_idx; i--) {
      double candidate_price;
      bool is_more_extreme;

      if(x_is_low) {
         candidate_price = iHigh(_Symbol, _Period, i);
         is_more_extreme = (candidate_price > a_price);
      } else {
         candidate_price = iLow(_Symbol, _Period, i);
         is_more_extreme = (candidate_price < a_price);
      }

      if(is_more_extreme) {
         a_idx = i;
         a_price = candidate_price;
         g_wave.a_idx = a_idx;
         g_wave.a_price = a_price;
         g_wave.x_less_than_a = (x_price < a_price);

         // Recompute B retracement with new A
         double new_xb_retrace = (b_price - x_price) / (a_price - x_price) * 100;
         if(new_xb_retrace < x_to_a_b_min || new_xb_retrace > x_to_a_b_max) return false;
      }
   }

   // Validate XB slope
   if(!validate_xb_segment(x_idx, b_idx, x_price, xb_slope, x_is_low)) return false;

   // Rule 1.13/2.13: X→B span containment with buffer
   // X<A: LOWs >= XB - buffer, X>A: HIGHs <= XB + buffer
   if(!validate_span_containment(x_idx, x_price, b_idx, b_price, !g_wave.x_less_than_a)) return false;

   // Calculate P point
   int bars_p_x = (int)(px_length_percentage * 0.01 * bars_x_b);
   if(Bars(_Symbol, _Period) - x_idx < bars_p_x) return false;
   g_wave.p_idx = x_idx + bars_p_x;
   g_wave.p_price = x_price - (bars_p_x * xb_slope);
   
   // Validate PX segment
   if(!validate_px_segment(g_wave.p_idx, x_idx, g_wave.p_price, xb_slope, x_is_low)) return false;
   
   double a_slope = get_a_channel_slope(xb_slope, g_wave.x_less_than_a);

   // XAB pattern: finalize here before searching for C
   if(pattern_type == XAB) {
      g_wave.is_bullish = determine_pattern_bullish(g_wave.b_price, g_wave.a_price);
      if(finalize_pattern(XAB, last_drawn_idx))
         return true;
      return false;
   }

   // Proxy AB validation removed — the proxy slope (derived from XB, not real A→C)
   // can over-restrict patterns, especially Non_Parallel where proxy = -xb_slope.
   // The real AB re-validation using actual AC slope happens inside
   // get_point_c_candidates() at lines 599-611 after C is found.

   bool c_is_low = next_point_is_low(b_price, a_price);

   //=================================================================
   // Get ALL C candidates and try each
   //=================================================================
   int c_candidates[];
   double c_prices[];
   get_point_c_candidates(bars_x_b, xb_slope, a_slope, c_is_low, c_candidates, c_prices);
   
   if(ArraySize(c_candidates) == 0) return false;
   
   for(int cc = 0; cc < ArraySize(c_candidates); cc++) {
      g_wave.c_idx = c_candidates[cc];
      g_wave.c_price = c_prices[cc];
      
      if(pattern_type == XABC) {
         g_wave.is_bullish = determine_pattern_bullish(g_wave.c_price, g_wave.b_price);
         if(finalize_pattern(XABC, last_drawn_idx))
            return true;  // Success! Pattern found
         continue;  // Try next C candidate if finalize_pattern failed
      }
      
      // Try to find D with this C
      bool d_is_low = next_point_is_low(g_wave.c_price, g_wave.b_price);
      int d_candidates[];
      double d_prices[];
      get_point_d_candidates(bars_x_b, xb_slope, d_is_low, d_candidates, d_prices);
      
      if(ArraySize(d_candidates) == 0) continue; // Try next C
      
      for(int dc = 0; dc < ArraySize(d_candidates); dc++) {
         g_wave.d_idx = d_candidates[dc];
         g_wave.d_price = d_prices[dc];
         
         if(pattern_type == XABCD) {
            g_wave.is_bullish = determine_pattern_bullish(g_wave.d_price, g_wave.c_price);
            if(finalize_pattern(XABCD, last_drawn_idx))
               return true;  // Success! Pattern found
            continue;  // Try next D candidate if finalize_pattern failed
         }
         
         // Try to find E with this D
         bool e_is_low = next_point_is_low(g_wave.d_price, g_wave.c_price);
         int e_candidates[];
         double e_prices[];
         get_point_e_candidates(bars_x_b, a_slope, e_is_low, e_candidates, e_prices);
         
         if(ArraySize(e_candidates) == 0) continue; // Try next D
         
         for(int ec = 0; ec < ArraySize(e_candidates); ec++) {
            g_wave.e_idx = e_candidates[ec];
            g_wave.e_price = e_prices[ec];
            
            if(pattern_type == XABCDE) {
               g_wave.is_bullish = determine_pattern_bullish(g_wave.e_price, g_wave.d_price);
               if(finalize_pattern(XABCDE, last_drawn_idx))
                  return true;  // Success! Pattern found
               continue;  // Try next E candidate if finalize_pattern failed
            }
            
            // Try to find F with this E
            bool f_is_low = next_point_is_low(g_wave.e_price, g_wave.d_price);
            int f_candidates[];
            double f_prices[];
            get_point_f_candidates(bars_x_b, xb_slope, f_is_low, f_candidates, f_prices);
            
            if(ArraySize(f_candidates) == 0) continue; // Try next E
            
            // Try each F candidate
            for(int fc = 0; fc < ArraySize(f_candidates); fc++) {
               g_wave.f_idx = f_candidates[fc];
               g_wave.f_price = f_prices[fc];
               g_wave.is_bullish = determine_pattern_bullish(g_wave.f_price, g_wave.e_price);
               if(finalize_pattern(XABCDEF, last_drawn_idx))
                  return true;  // Success! Pattern found
               // Try next F candidate if finalize_pattern failed
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Validate XB segment - LOWs or HIGHs must respect XB slope         |
//+------------------------------------------------------------------+
bool validate_xb_segment(int x_idx, int b_idx, double x_price, double xb_slope, bool check_lows) {
   for(int i = x_idx - 1; i > b_idx; i--) {
      double xb_value = x_price + (x_idx - i) * xb_slope;
      double price = check_lows ? iLow(_Symbol, _Period, i) : iHigh(_Symbol, _Period, i);
      // Spec 1.2/2.2: STRICT operators — candles must not touch the XB slope line
      if(check_lows ? (price <= xb_value) : (price >= xb_value)) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Validate PX segment                                               |
//+------------------------------------------------------------------+
bool validate_px_segment(int p_idx, int x_idx, double p_price, double xb_slope, bool check_lows) {
   for(int i = p_idx; i > x_idx; i--) {
      double px_value = p_price + (p_idx - i) * xb_slope;
      double price = check_lows ? iLow(_Symbol, _Period, i) : iHigh(_Symbol, _Period, i);
      if(check_lows ? (price < px_value) : (price > px_value)) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Validate A→B segment — candles between A and B against AC slope   |
//| Spec 1.3 (X<A): All Highs between A and B <= AC slope + buffer   |
//| Spec 2.3 (X>A): All Lows between A and B >= AC slope - buffer    |
//| Uses A-channel slope as proxy since C is not yet discovered       |
//| Buffer applied (blue line) — fresh slope, not extension           |
//+------------------------------------------------------------------+
bool validate_ab_segment(double ac_proxy_slope) {
   bool x_lt_a = g_wave.x_less_than_a;

   for(int i = g_wave.a_idx - 1; i > g_wave.b_idx; i--) {
      double ac_val = g_wave.a_price + (g_wave.a_idx - i) * ac_proxy_slope;
      double ac_buffer = MathAbs(ac_val) * slope_buffer_pct / 100.0;

      if(x_lt_a) {
         // Spec 1.3: All High prices between A and B <= AC slope + buffer
         double high = iHigh(_Symbol, _Period, i);
         if(high > ac_val + ac_buffer) return false;
      } else {
         // Spec 2.3: All Low prices between A and B >= AC slope - buffer
         double low = iLow(_Symbol, _Period, i);
         if(low < ac_val - ac_buffer) return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| Get A channel slope based on channel type                         |
//+------------------------------------------------------------------+
double get_a_channel_slope(double xb_slope, bool x_less_than_a) {
   switch(active_channel_type) {
      case Parallel:     return xb_slope;
      case Straight:     return 0.0;
      case Non_Parallel: return -1.0 * xb_slope;
      default:           return xb_slope;
   }
}

//+------------------------------------------------------------------+
//| Check if price is in channel                                      |
//+------------------------------------------------------------------+
bool is_in_channel(double price, double center, double upper_pct, double lower_pct) {
   double upper = center + MathAbs(center) * upper_pct * 0.01;
   double lower = center - MathAbs(center) * lower_pct * 0.01;
   return (price >= lower && price <= upper);
}

//+------------------------------------------------------------------+
//| Get ALL valid C candidates in A-channel extension                 |
//| Returns sorted array (most extreme first based on A>B logic)      |
//+------------------------------------------------------------------+
void get_point_c_candidates(int bars_x_b, double xb_slope, double a_slope, bool c_is_low,
                            int& candidates[], double& prices[]) {
   ArrayResize(candidates, 0);
   ArrayResize(prices, 0);
   
   int c_min_idx = g_wave.b_idx - (int)(bars_x_b * min_b_to_c_btw_x_b * 0.01);
   int c_max_idx = g_wave.b_idx - (int)(bars_x_b * max_b_to_c_btw_x_b * 0.01);
   if(c_min_idx >= g_wave.b_idx) c_min_idx = g_wave.b_idx - 1;
   if(c_max_idx < 1) c_max_idx = 1;
   
   // Sort by extremeness: seeking LOW → sort lowest first, seeking HIGH → sort highest first
   bool take_extreme_high = !c_is_low;

   for(int i = c_min_idx; i >= c_max_idx && i > 0; i--) {
      double c_price = c_is_low ? iLow(_Symbol, _Period, i) : iHigh(_Symbol, _Period, i);
      
      // Check if C is in A-channel (swap upper/lower for X>A)
      double a_channel_center = g_wave.a_price + (g_wave.a_idx - i) * a_slope;
      if(!is_in_channel(c_price, a_channel_center,
         g_wave.x_less_than_a ? a_upper_width_pct : a_lower_width_pct,
         g_wave.x_less_than_a ? a_lower_width_pct : a_upper_width_pct)) continue;
      
      // Check local extremum
      double prev = c_is_low ? iLow(_Symbol, _Period, i+1) : iHigh(_Symbol, _Period, i+1);
      double next = c_is_low ? iLow(_Symbol, _Period, i-1) : iHigh(_Symbol, _Period, i-1);
      if(c_is_low ? !(c_price <= prev && c_price <= next) : !(c_price >= prev && c_price >= next)) continue;
      
      // Calculate AC slope for validation
      int bars_a_c = g_wave.a_idx - i;
      if(bars_a_c <= 0) continue;
      double step_ac = (c_price - g_wave.a_price) / bars_a_c;

      // Fix 1: Re-validate A→B segment with REAL AC slope (not proxy)
      // The initial validate_ab_segment() used a proxy slope from get_a_channel_slope().
      // Now that C is found, re-check A→B candles against the actual AC slope.
      bool ab_revalid = true;
      for(int j = g_wave.a_idx - 1; j > g_wave.b_idx; j--) {
         double real_ac_val = g_wave.a_price + (g_wave.a_idx - j) * step_ac;
         double ac_buf = MathAbs(real_ac_val) * slope_buffer_pct / 100.0;
         if(g_wave.x_less_than_a) {
            // Rule 1.3: highs <= AC slope + buffer (blue line)
            if(iHigh(_Symbol, _Period, j) > real_ac_val + ac_buf) { ab_revalid = false; break; }
         } else {
            // Rule 2.3: lows >= AC slope - buffer (blue line)
            if(iLow(_Symbol, _Period, j) < real_ac_val - ac_buf) { ab_revalid = false; break; }
         }
      }
      if(!ab_revalid) continue;

      // Validate B→C segment
      if(!validate_bc_segment(i, xb_slope, step_ac)) continue;

      // Rule 1.14/2.14: A→C span containment with buffer
      // X<A: HIGHs <= AC + buffer, X>A: LOWs >= AC - buffer
      if(!validate_span_containment(g_wave.a_idx, g_wave.a_price, i, c_price, g_wave.x_less_than_a)) continue;

      // Add to candidates
      int size = ArraySize(candidates);
      ArrayResize(candidates, size + 1);
      ArrayResize(prices, size + 1);
      candidates[size] = i;
      prices[size] = c_price;
   }
   
   // Sort by extremeness (most extreme first)
   for(int i = 0; i < ArraySize(candidates) - 1; i++) {
      for(int j = i + 1; j < ArraySize(candidates); j++) {
         bool should_swap = take_extreme_high ? 
            (prices[j] > prices[i]) : (prices[j] < prices[i]);
         if(should_swap) {
            int tmp_idx = candidates[i]; candidates[i] = candidates[j]; candidates[j] = tmp_idx;
            double tmp_price = prices[i]; prices[i] = prices[j]; prices[j] = tmp_price;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Validate B→C segment                                              |
//| Buffer: AC gets buffer (starts from B), XB is strict              |
//| X<A: Support=XB ext (strict), Resistance=AC +buffer (above)       |
//| X>A: Resistance=XB ext (strict), Support=AC -buffer (below)       |
//+------------------------------------------------------------------+
bool validate_bc_segment(int c_idx, double xb_slope, double ac_slope) {
   bool x_lt_a = g_wave.x_less_than_a;
   
   for(int i = g_wave.b_idx - 1; i > c_idx; i--) {
      double xb_ext = g_wave.x_price + (g_wave.x_idx - i) * xb_slope;
      double ac_val = g_wave.a_price + (g_wave.a_idx - i) * ac_slope;
      double ac_buffer = MathAbs(ac_val) * slope_buffer_pct / 100.0;
      
      double low = iLow(_Symbol, _Period, i);
      double high = iHigh(_Symbol, _Period, i);
      
      if(x_lt_a) {
         // X<A: LOWs >= XB ext (strict), HIGHs <= AC + buffer (above)
         if(low < xb_ext) return false;
         if(high > ac_val + ac_buffer) return false;
      } else {
         // X>A: HIGHs <= XB ext (strict), LOWs >= AC - buffer (below)
         if(high > xb_ext) return false;
         if(low < ac_val - ac_buffer) return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| Get ALL valid D candidates in XB-channel extension                |
//| Returns sorted array (most extreme first based on A>B logic)      |
//+------------------------------------------------------------------+
void get_point_d_candidates(int bars_x_b, double xb_slope, bool d_is_low,
                            int& candidates[], double& prices[]) {
   ArrayResize(candidates, 0);
   ArrayResize(prices, 0);
   
   int d_min_idx = g_wave.c_idx - (int)(bars_x_b * min_c_to_d_btw_x_b * 0.01);
   int d_max_idx = g_wave.c_idx - (int)(bars_x_b * max_c_to_d_btw_x_b * 0.01);
   if(d_min_idx >= g_wave.c_idx) d_min_idx = g_wave.c_idx - 1;
   if(d_max_idx < 1) d_max_idx = 1;
   
   // Sort by extremeness: seeking LOW → sort lowest first, seeking HIGH → sort highest first
   bool take_extreme_high = !d_is_low;

   // Calculate AC slope for extension
   double step_ac = (g_wave.c_price - g_wave.a_price) / (g_wave.a_idx - g_wave.c_idx);
   
   for(int i = d_min_idx; i >= d_max_idx && i > 0; i--) {
      double d_price = d_is_low ? iLow(_Symbol, _Period, i) : iHigh(_Symbol, _Period, i);
      
      // Check if D is in XB-channel (swap upper/lower for X>A)
      double xb_center = g_wave.x_price + (g_wave.x_idx - i) * xb_slope;
      if(!is_in_channel(d_price, xb_center,
         g_wave.x_less_than_a ? xb_upper_width_pct : xb_lower_width_pct,
         g_wave.x_less_than_a ? xb_lower_width_pct : xb_upper_width_pct)) continue;
      
      // Check local extremum
      double prev = d_is_low ? iLow(_Symbol, _Period, i+1) : iHigh(_Symbol, _Period, i+1);
      double next = d_is_low ? iLow(_Symbol, _Period, i-1) : iHigh(_Symbol, _Period, i-1);
      if(d_is_low ? !(d_price <= prev && d_price <= next) : !(d_price >= prev && d_price >= next)) continue;
      
      // Calculate BD slope
      int bars_b_d = g_wave.b_idx - i;
      if(bars_b_d <= 0) continue;
      double step_bd = (d_price - g_wave.b_price) / bars_b_d;

      // Fix 2: Validate B→C candles against BD slope
      // Now that D is found and BD slope is known, ensure ALL candles from B to C
      // also respect the BD slope (same buffer rules as C→D per rule 1.7/2.7).
      bool bc_bd_valid = true;
      for(int j = g_wave.b_idx - 1; j > g_wave.c_idx; j--) {
         double bd_val = g_wave.b_price + (g_wave.b_idx - j) * step_bd;
         double bd_buffer = MathAbs(bd_val) * slope_buffer_pct / 100.0;
         if(g_wave.x_less_than_a) {
            // Rule 1.7 extended: lows >= BD slope - buffer
            if(iLow(_Symbol, _Period, j) < bd_val - bd_buffer) { bc_bd_valid = false; break; }
         } else {
            // Rule 2.7 extended: highs <= BD slope + buffer
            if(iHigh(_Symbol, _Period, j) > bd_val + bd_buffer) { bc_bd_valid = false; break; }
         }
      }
      if(!bc_bd_valid) continue;

      // Validate C→D segment
      if(!validate_cd_segment(i, step_ac, step_bd)) continue;

      // Rule 1.15/2.15: B→D span containment with buffer
      // X<A: LOWs >= BD - buffer, X>A: HIGHs <= BD + buffer
      if(!validate_span_containment(g_wave.b_idx, g_wave.b_price, i, d_price, !g_wave.x_less_than_a)) continue;

      // Add to candidates
      int size = ArraySize(candidates);
      ArrayResize(candidates, size + 1);
      ArrayResize(prices, size + 1);
      candidates[size] = i;
      prices[size] = d_price;
   }
   
   // Sort by extremeness
   for(int i = 0; i < ArraySize(candidates) - 1; i++) {
      for(int j = i + 1; j < ArraySize(candidates); j++) {
         bool should_swap = take_extreme_high ? 
            (prices[j] > prices[i]) : (prices[j] < prices[i]);
         if(should_swap) {
            int tmp_idx = candidates[i]; candidates[i] = candidates[j]; candidates[j] = tmp_idx;
            double tmp_price = prices[i]; prices[i] = prices[j]; prices[j] = tmp_price;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Validate C→D segment                                              |
//| Buffer: BD gets buffer (starts from C), AC ext is strict          |
//| X<A: Support=BD -buffer (below), Resistance=AC ext (strict)       |
//| X>A: Resistance=BD +buffer (above), Support=AC ext (strict)       |
//+------------------------------------------------------------------+
bool validate_cd_segment(int d_idx, double ac_slope, double bd_slope) {
   bool x_lt_a = g_wave.x_less_than_a;
   
   for(int i = g_wave.c_idx - 1; i > d_idx; i--) {
      double ac_ext = g_wave.a_price + (g_wave.a_idx - i) * ac_slope;
      double bd_val = g_wave.b_price + (g_wave.b_idx - i) * bd_slope;
      double bd_buffer = MathAbs(bd_val) * slope_buffer_pct / 100.0;
      
      double low = iLow(_Symbol, _Period, i);
      double high = iHigh(_Symbol, _Period, i);
      
      if(x_lt_a) {
         // X<A: LOWs >= BD - buffer (below), HIGHs < AC ext (strict)
         if(low < bd_val - bd_buffer) return false;
         if(high >= ac_ext) return false;
      } else {
         // X>A: Spec 2.7: HIGHs <= BD + buffer, Spec 2.6: LOWs > AC ext (strict)
         if(high > bd_val + bd_buffer) return false;
         if(low <= ac_ext) return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| Find E point in A-channel extension                               |
//| E is same type as C (opposite from D)                             |
//| Selection: A>B logic (same as C selection)                        |
//+------------------------------------------------------------------+
//| Get ALL valid E candidates in A-channel extension                 |
//+------------------------------------------------------------------+
void get_point_e_candidates(int bars_x_b, double a_slope, bool e_is_low,
                            int& candidates[], double& prices[]) {
   ArrayResize(candidates, 0);
   ArrayResize(prices, 0);
   
   int e_min_idx = g_wave.d_idx - (int)(bars_x_b * min_d_to_e_btw_x_b * 0.01);
   int e_max_idx = g_wave.d_idx - (int)(bars_x_b * max_d_to_e_btw_x_b * 0.01);
   if(e_min_idx >= g_wave.d_idx) e_min_idx = g_wave.d_idx - 1;
   if(e_max_idx < 1) e_max_idx = 1;
   
   // Sort by extremeness: seeking LOW → sort lowest first, seeking HIGH → sort highest first
   bool take_extreme_high = !e_is_low;

   double step_bd = (g_wave.d_price - g_wave.b_price) / (g_wave.b_idx - g_wave.d_idx);
   
   for(int i = e_min_idx; i >= e_max_idx && i > 0; i--) {
      double e_price = e_is_low ? iLow(_Symbol, _Period, i) : iHigh(_Symbol, _Period, i);
      
      double a_center = g_wave.a_price + (g_wave.a_idx - i) * a_slope;
      if(!is_in_channel(e_price, a_center,
         g_wave.x_less_than_a ? a_upper_width_pct : a_lower_width_pct,
         g_wave.x_less_than_a ? a_lower_width_pct : a_upper_width_pct)) continue;
      
      double prev = e_is_low ? iLow(_Symbol, _Period, i+1) : iHigh(_Symbol, _Period, i+1);
      double next = e_is_low ? iLow(_Symbol, _Period, i-1) : iHigh(_Symbol, _Period, i-1);
      if(e_is_low ? !(e_price <= prev && e_price <= next) : !(e_price >= prev && e_price >= next)) continue;
      
      int bars_c_e = g_wave.c_idx - i;
      if(bars_c_e <= 0) continue;
      double step_ce = (e_price - g_wave.c_price) / bars_c_e;

      // Fix 3: Re-validate C→D segment with real CE slope
      // Analogous to Fix 1 (A→B vs AC): now that E is found and CE slope is known,
      // ensure all candles between C and D respect the CE slope line.
      bool cd_revalid = true;
      for(int j = g_wave.c_idx - 1; j > g_wave.d_idx; j--) {
         double real_ce_val = g_wave.c_price + (g_wave.c_idx - j) * step_ce;
         double ce_buf = MathAbs(real_ce_val) * slope_buffer_pct / 100.0;
         if(g_wave.x_less_than_a) {
            // Rule 1.9 analog: highs <= CE slope + buffer (blue line)
            if(iHigh(_Symbol, _Period, j) > real_ce_val + ce_buf) { cd_revalid = false; break; }
         } else {
            // Rule 2.9 analog: lows >= CE slope - buffer (blue line)
            if(iLow(_Symbol, _Period, j) < real_ce_val - ce_buf) { cd_revalid = false; break; }
         }
      }
      if(!cd_revalid) continue;

      if(!validate_de_segment(i, step_bd, step_ce)) continue;

      // Rule 1.16/2.16: C→E span containment with buffer
      // X<A: HIGHs <= CE + buffer, X>A: LOWs >= CE - buffer
      if(!validate_span_containment(g_wave.c_idx, g_wave.c_price, i, e_price, g_wave.x_less_than_a)) continue;

      // Add to candidates
      int size = ArraySize(candidates);
      ArrayResize(candidates, size + 1);
      ArrayResize(prices, size + 1);
      candidates[size] = i;
      prices[size] = e_price;
   }
   
   // Sort by extremeness
   for(int i = 0; i < ArraySize(candidates) - 1; i++) {
      for(int j = i + 1; j < ArraySize(candidates); j++) {
         bool should_swap = take_extreme_high ? 
            (prices[j] > prices[i]) : (prices[j] < prices[i]);
         if(should_swap) {
            int tmp_idx = candidates[i]; candidates[i] = candidates[j]; candidates[j] = tmp_idx;
            double tmp_price = prices[i]; prices[i] = prices[j]; prices[j] = tmp_price;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Validate D→E segment                                              |
//| Buffer: CE gets buffer (starts from D), BD ext is strict          |
//| X<A: Support=BD ext (strict), Resistance=CE +buffer (above)       |
//| X>A: Resistance=BD ext (strict), Support=CE -buffer (below)       |
//+------------------------------------------------------------------+
bool validate_de_segment(int e_idx, double bd_slope, double ce_slope) {
   bool x_lt_a = g_wave.x_less_than_a;
   
   for(int i = g_wave.d_idx - 1; i > e_idx; i--) {
      double bd_ext = g_wave.b_price + (g_wave.b_idx - i) * bd_slope;
      double ce_val = g_wave.c_price + (g_wave.c_idx - i) * ce_slope;
      double ce_buffer = MathAbs(ce_val) * slope_buffer_pct / 100.0;
      
      double low = iLow(_Symbol, _Period, i);
      double high = iHigh(_Symbol, _Period, i);
      
      if(x_lt_a) {
         // Spec 1.8: LOWs > BD ext (strict), Spec 1.9: HIGHs <= CE + buffer
         if(low <= bd_ext) return false;
         if(high > ce_val + ce_buffer) return false;
      } else {
         // Spec 2.8: HIGHs < BD ext (strict), Spec 2.9: LOWs >= CE - buffer
         if(high >= bd_ext) return false;
         if(low < ce_val - ce_buffer) return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| Find F point in XB-channel extension                              |
//| F is same type as D (opposite from E)                             |
//| Selection: A>B logic (same as D selection)                        |
//+------------------------------------------------------------------+
//| Get ALL valid F candidates in XB-channel extension                |
//+------------------------------------------------------------------+
void get_point_f_candidates(int bars_x_b, double xb_slope, bool f_is_low,
                            int& candidates[], double& prices[]) {
   ArrayResize(candidates, 0);
   ArrayResize(prices, 0);
   
   int f_min_idx = g_wave.e_idx - (int)(bars_x_b * min_e_to_f_btw_x_b * 0.01);
   int f_max_idx = g_wave.e_idx - (int)(bars_x_b * max_e_to_f_btw_x_b * 0.01);
   if(f_min_idx >= g_wave.e_idx) f_min_idx = g_wave.e_idx - 1;
   if(f_max_idx < 1) f_max_idx = 1;
   
   // Sort by extremeness: seeking LOW → sort lowest first, seeking HIGH → sort highest first
   bool take_extreme_high = !f_is_low;
   
   double step_ce = (g_wave.e_price - g_wave.c_price) / (g_wave.c_idx - g_wave.e_idx);
   
   for(int i = f_min_idx; i >= f_max_idx && i > 0; i--) {
      double f_price = f_is_low ? iLow(_Symbol, _Period, i) : iHigh(_Symbol, _Period, i);
      
      double xb_center = g_wave.x_price + (g_wave.x_idx - i) * xb_slope;
      if(!is_in_channel(f_price, xb_center,
         g_wave.x_less_than_a ? xb_upper_width_pct : xb_lower_width_pct,
         g_wave.x_less_than_a ? xb_lower_width_pct : xb_upper_width_pct)) continue;
      
      double prev = f_is_low ? iLow(_Symbol, _Period, i+1) : iHigh(_Symbol, _Period, i+1);
      double next = f_is_low ? iLow(_Symbol, _Period, i-1) : iHigh(_Symbol, _Period, i-1);
      if(f_is_low ? !(f_price <= prev && f_price <= next) : !(f_price >= prev && f_price >= next)) continue;
      
      int bars_d_f = g_wave.d_idx - i;
      if(bars_d_f <= 0) continue;
      double step_df = (f_price - g_wave.d_price) / bars_d_f;

      // Fix 4: Validate D→E candles against DF slope
      // Analogous to Fix 2 (B→C vs BD): now that F is found and DF slope is known,
      // ensure all candles between D and E respect the DF slope line.
      bool de_df_valid = true;
      for(int j = g_wave.d_idx - 1; j > g_wave.e_idx; j--) {
         double df_val = g_wave.d_price + (g_wave.d_idx - j) * step_df;
         double df_buffer = MathAbs(df_val) * slope_buffer_pct / 100.0;
         if(g_wave.x_less_than_a) {
            // Rule 1.7 analog: lows >= DF slope - buffer
            if(iLow(_Symbol, _Period, j) < df_val - df_buffer) { de_df_valid = false; break; }
         } else {
            // Rule 2.7 analog: highs <= DF slope + buffer
            if(iHigh(_Symbol, _Period, j) > df_val + df_buffer) { de_df_valid = false; break; }
         }
      }
      if(!de_df_valid) continue;

      if(!validate_ef_segment(i, step_ce, step_df)) continue;

      // Rule 1.17/2.17: D→F span containment with buffer
      // X<A: LOWs >= DF - buffer, X>A: HIGHs <= DF + buffer
      if(!validate_span_containment(g_wave.d_idx, g_wave.d_price, i, f_price, !g_wave.x_less_than_a)) continue;

      // Add to candidates
      int size = ArraySize(candidates);
      ArrayResize(candidates, size + 1);
      ArrayResize(prices, size + 1);
      candidates[size] = i;
      prices[size] = f_price;
   }
   
   // Sort by extremeness
   for(int i = 0; i < ArraySize(candidates) - 1; i++) {
      for(int j = i + 1; j < ArraySize(candidates); j++) {
         bool should_swap = take_extreme_high ? 
            (prices[j] > prices[i]) : (prices[j] < prices[i]);
         if(should_swap) {
            int tmp_idx = candidates[i]; candidates[i] = candidates[j]; candidates[j] = tmp_idx;
            double tmp_price = prices[i]; prices[i] = prices[j]; prices[j] = tmp_price;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Validate E→F segment                                              |
//| Buffer: DF gets buffer (starts from E), CE ext is strict          |
//| X<A: Support=DF -buffer (below), Resistance=CE ext (strict)       |
//| X>A: Resistance=DF +buffer (above), Support=CE ext (strict)       |
//+------------------------------------------------------------------+
bool validate_ef_segment(int f_idx, double ce_slope, double df_slope) {
   bool x_lt_a = g_wave.x_less_than_a;
   
   for(int i = g_wave.e_idx - 1; i > f_idx; i--) {
      double ce_ext = g_wave.c_price + (g_wave.c_idx - i) * ce_slope;
      double df_val = g_wave.d_price + (g_wave.d_idx - i) * df_slope;
      double df_buffer = MathAbs(df_val) * slope_buffer_pct / 100.0;
      
      double low = iLow(_Symbol, _Period, i);
      double high = iHigh(_Symbol, _Period, i);
      
      if(x_lt_a) {
         // X<A: LOWs >= DF - buffer (below), HIGHs < CE ext (strict)
         if(low < df_val - df_buffer) return false;
         if(high >= ce_ext) return false;
      } else {
         // Spec 2.11: HIGHs <= DF + buffer, Spec 2.10: LOWs > CE ext (strict)
         if(high > df_val + df_buffer) return false;
         if(low <= ce_ext) return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| Validate same-side span containment (rules 1.13-1.17, 2.13-2.17) |
//| Checks ALL candles between two same-side points against their     |
//| connecting slope with buffer applied.                             |
//| check_upper=true: HIGHs <= slope + buffer                        |
//| check_upper=false: LOWs >= slope - buffer                        |
//+------------------------------------------------------------------+
bool validate_span_containment(int point1_idx, double point1_price,
                                int point2_idx, double point2_price,
                                bool check_upper) {
   int bars = point1_idx - point2_idx;
   if(bars <= 0) return true;
   double slope = (point2_price - point1_price) / bars;

   for(int i = point1_idx - 1; i > point2_idx; i--) {
      double slope_val = point1_price + (point1_idx - i) * slope;
      double buffer = MathAbs(slope_val) * slope_buffer_pct / 100.0;

      if(check_upper) {
         if(iHigh(_Symbol, _Period, i) > slope_val + buffer) return false;
      } else {
         if(iLow(_Symbol, _Period, i) < slope_val - buffer) return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| Finalize and draw pattern                                         |
//+------------------------------------------------------------------+
bool finalize_pattern(pattern_type_enum ptype, int& last_drawn_idx) {
   int last_idx;
   switch(ptype) {
      case XAB: last_idx = g_wave.b_idx; break;
      case XABC: last_idx = g_wave.c_idx; break;
      case XABCD: last_idx = g_wave.d_idx; break;
      case XABCDE: last_idx = g_wave.e_idx; break;
      case XABCDEF: last_idx = g_wave.f_idx; break;
      default: return false;
   }

   // Apply tick speed filter
   if(!tick_speed_filter(g_wave.x_idx, last_idx))
      return false;
   
   // Apply divergence filter based on pattern type
   int direction = g_wave.is_bullish ? 1 : -1;
   switch(ptype) {
      case XAB:
         if(!divergence_filter(g_wave.x_idx, g_wave.a_idx, g_wave.b_idx, direction))
            return false;
         break;
      case XABC:
         if(!divergence_filter(g_wave.a_idx, g_wave.b_idx, g_wave.c_idx, direction))
            return false;
         break;
      case XABCD:
         if(!divergence_filter(g_wave.b_idx, g_wave.c_idx, g_wave.d_idx, direction))
            return false;
         break;
      case XABCDE:
         if(!divergence_filter(g_wave.c_idx, g_wave.d_idx, g_wave.e_idx, direction))
            return false;
         break;
      case XABCDEF:
         if(!divergence_filter(g_wave.d_idx, g_wave.e_idx, g_wave.f_idx, direction))
            return false;
         break;
   }
   
   // Filter by pattern direction (user choice)
   // Pattern direction is auto-detected: bullish = last < prev, bearish = last > prev
   if(pattern_direction == Bullish && !g_wave.is_bullish)
      return false;  // User wants bullish only, but this pattern is bearish
   if(pattern_direction == Bearish && g_wave.is_bullish)
      return false;  // User wants bearish only, but this pattern is bullish
   // If pattern_direction == Both, show all patterns
   
   // Check overlap
   if(only_draw_most_recent && min_bars_between_patterns > 0) {
      if(last_drawn_idx - last_idx < min_bars_between_patterns && last_drawn_idx != -9999)
         return false;
   }
   last_drawn_idx = last_idx;
   
   // Draw pattern
   string dir_str = g_wave.is_bullish ? " [BULLISH]" : " [BEARISH]";
   Print("V2: Drawing pattern ", EnumToString(ptype), dir_str, " at X=", g_wave.x_idx);
   
   if(draw_pattern_lines) draw_pattern(ptype);
   if(draw_channel_lines) draw_channels(ptype);
   if(draw_labels) draw_all_labels(ptype);
   
   // Golden Line for initial pattern
   // IMPORTANT: Golden line type is based on pattern CONFIGURATION (x_less_than_a)
   // NOT pattern direction (is_bullish)
   // x_less_than_a = true → UPTREND config → X is LOW → use LOWs → SELL signal
   // x_less_than_a = false → DOWNTREND config → X is HIGH → use HIGHs → BUY signal
   if(draw_golden_line && ptype >= XAB) {
      Print("V2: Calling ", (g_wave.x_less_than_a ? "golden_line_UPTREND" : "golden_line_DOWNTREND"),
            " for pattern at X=", g_wave.x_idx, " (x_less_than_a=", g_wave.x_less_than_a, ")");
      if(g_wave.x_less_than_a)
         golden_line_uptrend(ptype);
      else
         golden_line_downtrend(ptype);
   }

   // Dynamic Last Point tracking for live trading
   if(enable_dynamic_last_point && ptype >= XAB) {
      track_dynamic_last_points(ptype);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Track Dynamic Last Points for live trading                        |
//| Monitors slope extension and updates last point when broken       |
//| Draws Golden Line for each new last point found                   |
//| CONSTRAINTS (ALL 3 MUST PASS):                                     |
//|   1. Must be within input length limits                           |
//|   2. Must be within channel (A-channel for C/E, XB-channel for D/F)|
//|   3. Must pass slope validation rules                              |
//+------------------------------------------------------------------+
void track_dynamic_last_points(pattern_type_enum ptype) {
   // Get current last point info and slope based on pattern type
   int prev_idx, last_idx;
   double prev_price, last_price;
   int search_origin_idx;  // Reference point for calculating valid range
   double min_pct, max_pct;  // Input parameters for valid range
   bool use_a_channel;  // true = A-channel (C, E), false = XB-channel (D, F)
   
   // Calculate bars_x_b for percentage calculations
   int bars_x_b = g_wave.x_idx - g_wave.b_idx;
   if(bars_x_b <= 0) return;
   
   // Calculate XB slope and A-channel slope for channel validation
   double xb_slope = (g_wave.b_price - g_wave.x_price) / bars_x_b;
   double a_slope = get_a_channel_slope(xb_slope, g_wave.x_less_than_a);
   
   // Determine previous/last points, valid range, and channel type based on pattern type
   switch(ptype) {
      case XAB:
         prev_idx = g_wave.x_idx; prev_price = g_wave.x_price;
         last_idx = g_wave.b_idx; last_price = g_wave.b_price;
         search_origin_idx = g_wave.a_idx;  // B search extends from A onward
         min_pct = 0;
         max_pct = 100;
         use_a_channel = false;  // B is in XB-channel
         break;
      case XABC:
         prev_idx = g_wave.a_idx; prev_price = g_wave.a_price;
         last_idx = g_wave.c_idx; last_price = g_wave.c_price;
         search_origin_idx = g_wave.b_idx;  // C is measured from B
         min_pct = min_b_to_c_btw_x_b;
         max_pct = max_b_to_c_btw_x_b;
         use_a_channel = true;  // C is in A-channel
         break;
      case XABCD:
         prev_idx = g_wave.b_idx; prev_price = g_wave.b_price;
         last_idx = g_wave.d_idx; last_price = g_wave.d_price;
         search_origin_idx = g_wave.c_idx;  // D is measured from C
         min_pct = min_c_to_d_btw_x_b;
         max_pct = max_c_to_d_btw_x_b;
         use_a_channel = false;  // D is in XB-channel
         break;
      case XABCDE:
         prev_idx = g_wave.c_idx; prev_price = g_wave.c_price;
         last_idx = g_wave.e_idx; last_price = g_wave.e_price;
         search_origin_idx = g_wave.d_idx;  // E is measured from D
         min_pct = min_d_to_e_btw_x_b;
         max_pct = max_d_to_e_btw_x_b;
         use_a_channel = true;  // E is in A-channel
         break;
      case XABCDEF:
         prev_idx = g_wave.d_idx; prev_price = g_wave.d_price;
         last_idx = g_wave.f_idx; last_price = g_wave.f_price;
         search_origin_idx = g_wave.e_idx;  // F is measured from E
         min_pct = min_e_to_f_btw_x_b;
         max_pct = max_e_to_f_btw_x_b;
         use_a_channel = false;  // F is in XB-channel
         break;
      default: return;
   }
   
   // Calculate valid range boundaries based on input parameters
   // Dynamic last point must stay within: origin - (min% of XB) to origin - (max% of XB)
   int valid_range_start = search_origin_idx - (int)(bars_x_b * min_pct * 0.01);
   int valid_range_end = search_origin_idx - (int)(bars_x_b * max_pct * 0.01);
   if(valid_range_start >= search_origin_idx) valid_range_start = search_origin_idx - 1;
   if(valid_range_end < 1) valid_range_end = 1;
   
   Print("V2: Dynamic tracking - valid range: bar ", valid_range_start, " to bar ", valid_range_end,
         " (origin=", search_origin_idx, ", min%=", min_pct, ", max%=", max_pct, 
         ", channel=", (use_a_channel ? "A-channel" : "XB-channel"), ")");
   
   // Track dynamic last points
   int iteration = 0;
   int current_last_idx = last_idx;
   double current_last_price = last_price;
   int dynamic_point_count = 0;
   
   while(iteration < max_dynamic_iterations) {
      iteration++;
      
      // Calculate slope from prev to current last
      int bars_prev_to_last = prev_idx - current_last_idx;
      if(bars_prev_to_last <= 0) break;
      
      double slope = (current_last_price - prev_price) / bars_prev_to_last;
      
      // Search for breaks in the slope extension
      // Only search within the valid range defined by input parameters
      int new_last_idx = -1;
      double new_last_price = 0;
      int search_start = MathMin(current_last_idx - 1, valid_range_start);
      int search_end = MathMax(valid_range_end, 1);
      
      for(int i = search_start; i >= search_end; i--) {
         // Skip if outside valid range
         if(i > valid_range_start || i < valid_range_end) continue;
         
         // Calculate slope extension value at this bar
         int bars_from_prev = prev_idx - i;
         double slope_value = prev_price + bars_from_prev * slope;
         
         bool break_found = false;
         double candle_price;
         
         if(g_wave.is_bullish) {
            // BULLISH: last point is LOW, check if LOW breaks BELOW slope extension
            candle_price = iLow(_Symbol, _Period, i);
            if(candle_price < slope_value) {
               break_found = true;
            }
         } else {
            // BEARISH: last point is HIGH, check if HIGH breaks ABOVE slope extension
            candle_price = iHigh(_Symbol, _Period, i);
            if(candle_price > slope_value) {
               break_found = true;
            }
         }
         
         if(break_found) {
            // CONSTRAINT 2: CHANNEL VALIDATION
            // Check if point is within the appropriate channel
            double channel_center;
            bool in_channel;
            
            if(use_a_channel) {
               // C/E must be in A-channel
               channel_center = g_wave.a_price + (g_wave.a_idx - i) * a_slope;
               in_channel = is_in_channel(candle_price, channel_center,
                  g_wave.x_less_than_a ? a_upper_width_pct : a_lower_width_pct,
                  g_wave.x_less_than_a ? a_lower_width_pct : a_upper_width_pct);
            } else {
               // D/F must be in XB-channel
               channel_center = g_wave.x_price + (g_wave.x_idx - i) * xb_slope;
               in_channel = is_in_channel(candle_price, channel_center,
                  g_wave.x_less_than_a ? xb_upper_width_pct : xb_lower_width_pct,
                  g_wave.x_less_than_a ? xb_lower_width_pct : xb_upper_width_pct);
            }
            
            if(!in_channel) continue;  // Skip if not in channel
            
            // Check if this is a local extremum
            double prev_candle = g_wave.is_bullish ? iLow(_Symbol, _Period, i+1) : iHigh(_Symbol, _Period, i+1);
            double next_candle = g_wave.is_bullish ? iLow(_Symbol, _Period, i-1) : iHigh(_Symbol, _Period, i-1);
            
            bool is_extremum = g_wave.is_bullish ?
               (candle_price <= prev_candle && candle_price <= next_candle) :
               (candle_price >= prev_candle && candle_price >= next_candle);
            
            if(!is_extremum) continue;  // Skip if not local extremum
            
            // CONSTRAINT 3: SLOPE VALIDATION
            // All candles between previous point and new last point must respect slope boundaries
            bool slope_valid = validate_dynamic_segment(ptype, i, candle_price, xb_slope, a_slope);
            
            if(!slope_valid) {
               Print("V2: Dynamic point at idx=", i, " failed slope validation");
               continue;  // Skip if slope validation fails
            }
            
            new_last_idx = i;
            new_last_price = candle_price;
            break; // Found a valid break point
         }
      }
      
      // If no break found, we're done
      if(new_last_idx == -1) break;
      
      // Update current last point
      current_last_idx = new_last_idx;
      current_last_price = new_last_price;
      dynamic_point_count++;
      
      // Draw label for dynamic last point (white color)
      string dyn_label = "DYN_" + (string)g_wave.x_idx + "_" + (string)dynamic_point_count;
      draw_dynamic_last_point_label(dyn_label, current_last_idx, current_last_price, dynamic_point_count);
      
      // Update the global wave structure temporarily for Golden Line calculation
      update_wave_last_point(ptype, current_last_idx, current_last_price);
      
      // Draw Golden Line for this dynamic last point
      // Golden line type based on x_less_than_a (pattern configuration)
      Print("V2: Drawing Golden Line for dynamic last point #", dynamic_point_count, 
            " at idx=", current_last_idx, " price=", current_last_price,
            " (x_less_than_a=", g_wave.x_less_than_a, ")");
      
      if(g_wave.x_less_than_a)
         golden_line_uptrend(ptype);
      else
         golden_line_downtrend(ptype);
   }
   
   if(dynamic_point_count > 0) {
      Print("V2: Found ", dynamic_point_count, " dynamic last points for pattern at X=", g_wave.x_idx);
   }
}

//+------------------------------------------------------------------+
//| Validate slope for dynamic last point segment                      |
//| Uses the same slope validation rules as initial point detection    |
//| XAB:  X→B validation (XB slope)                                    |
//| XABC: B→C validation (XB ext + AC)                                 |
//| XABCD: C→D validation (BD + AC ext)                                |
//| XABCDE: D→E validation (BD ext + CE)                               |
//| XABCDEF: E→F validation (DF + CE ext)                              |
//+------------------------------------------------------------------+
bool validate_dynamic_segment(pattern_type_enum ptype, int new_last_idx, double new_last_price,
                               double xb_slope, double a_slope) {

   switch(ptype) {
      case XAB: {
         // X→B segment: validate_xb_segment logic with new B position
         double new_xb_slope = (new_last_price - g_wave.x_price) / (g_wave.x_idx - new_last_idx);
         if(!validate_xb_segment(g_wave.x_idx, new_last_idx, g_wave.x_price, new_xb_slope, g_wave.x_less_than_a)) return false;
         // Rule 1.13/2.13 (dynamic): X→B span containment
         return validate_span_containment(g_wave.x_idx, g_wave.x_price, new_last_idx, new_last_price, !g_wave.x_less_than_a);
      }
      case XABC: {
         // B→C segment: validate_bc_segment logic
         // Calculate AC slope with new C position
         int bars_a_c = g_wave.a_idx - new_last_idx;
         if(bars_a_c <= 0) return false;
         double ac_slope = (new_last_price - g_wave.a_price) / bars_a_c;
         // Fix 1 (dynamic): Re-validate A→B with new AC slope
         for(int j = g_wave.a_idx - 1; j > g_wave.b_idx; j--) {
            double real_ac_val = g_wave.a_price + (g_wave.a_idx - j) * ac_slope;
            double ac_buf = MathAbs(real_ac_val) * slope_buffer_pct / 100.0;
            if(g_wave.x_less_than_a) {
               if(iHigh(_Symbol, _Period, j) > real_ac_val + ac_buf) return false;
            } else {
               if(iLow(_Symbol, _Period, j) < real_ac_val - ac_buf) return false;
            }
         }
         if(!validate_bc_segment(new_last_idx, xb_slope, ac_slope)) return false;
         // Rule 1.14/2.14 (dynamic): A→C span containment
         return validate_span_containment(g_wave.a_idx, g_wave.a_price, new_last_idx, new_last_price, g_wave.x_less_than_a);
      }
      case XABCD: {
         // C→D segment: validate_cd_segment logic
         // Calculate BD slope with new D position
         int bars_a_c = g_wave.a_idx - g_wave.c_idx;
         if(bars_a_c <= 0) return false;
         double ac_slope = (g_wave.c_price - g_wave.a_price) / bars_a_c;
         int bars_b_d = g_wave.b_idx - new_last_idx;
         if(bars_b_d <= 0) return false;
         double bd_slope = (new_last_price - g_wave.b_price) / bars_b_d;
         // Fix 2 (dynamic): Validate B→C candles against new BD slope
         for(int j = g_wave.b_idx - 1; j > g_wave.c_idx; j--) {
            double bd_val = g_wave.b_price + (g_wave.b_idx - j) * bd_slope;
            double bd_buffer = MathAbs(bd_val) * slope_buffer_pct / 100.0;
            if(g_wave.x_less_than_a) {
               if(iLow(_Symbol, _Period, j) < bd_val - bd_buffer) return false;
            } else {
               if(iHigh(_Symbol, _Period, j) > bd_val + bd_buffer) return false;
            }
         }
         if(!validate_cd_segment(new_last_idx, ac_slope, bd_slope)) return false;
         // Rule 1.15/2.15 (dynamic): B→D span containment
         return validate_span_containment(g_wave.b_idx, g_wave.b_price, new_last_idx, new_last_price, !g_wave.x_less_than_a);
      }
      case XABCDE: {
         // D→E segment: validate_de_segment logic
         // Calculate CE slope with new E position
         int bars_b_d = g_wave.b_idx - g_wave.d_idx;
         if(bars_b_d <= 0) return false;
         double bd_slope = (g_wave.d_price - g_wave.b_price) / bars_b_d;
         int bars_c_e = g_wave.c_idx - new_last_idx;
         if(bars_c_e <= 0) return false;
         double ce_slope = (new_last_price - g_wave.c_price) / bars_c_e;
         // Fix 3 (dynamic): Re-validate C→D against new CE slope
         for(int j = g_wave.c_idx - 1; j > g_wave.d_idx; j--) {
            double real_ce_val = g_wave.c_price + (g_wave.c_idx - j) * ce_slope;
            double ce_buf = MathAbs(real_ce_val) * slope_buffer_pct / 100.0;
            if(g_wave.x_less_than_a) {
               if(iHigh(_Symbol, _Period, j) > real_ce_val + ce_buf) return false;
            } else {
               if(iLow(_Symbol, _Period, j) < real_ce_val - ce_buf) return false;
            }
         }
         if(!validate_de_segment(new_last_idx, bd_slope, ce_slope)) return false;
         // Rule 1.16/2.16 (dynamic): C→E span containment
         return validate_span_containment(g_wave.c_idx, g_wave.c_price, new_last_idx, new_last_price, g_wave.x_less_than_a);
      }
      case XABCDEF: {
         // E→F segment: validate_ef_segment logic
         // Calculate DF slope with new F position
         int bars_c_e = g_wave.c_idx - g_wave.e_idx;
         if(bars_c_e <= 0) return false;
         double ce_slope = (g_wave.e_price - g_wave.c_price) / bars_c_e;
         int bars_d_f = g_wave.d_idx - new_last_idx;
         if(bars_d_f <= 0) return false;
         double df_slope = (new_last_price - g_wave.d_price) / bars_d_f;
         // Fix 4 (dynamic): Validate D→E against new DF slope
         for(int j = g_wave.d_idx - 1; j > g_wave.e_idx; j--) {
            double df_val = g_wave.d_price + (g_wave.d_idx - j) * df_slope;
            double df_buffer = MathAbs(df_val) * slope_buffer_pct / 100.0;
            if(g_wave.x_less_than_a) {
               if(iLow(_Symbol, _Period, j) < df_val - df_buffer) return false;
            } else {
               if(iHigh(_Symbol, _Period, j) > df_val + df_buffer) return false;
            }
         }
         if(!validate_ef_segment(new_last_idx, ce_slope, df_slope)) return false;
         // Rule 1.17/2.17 (dynamic): D→F span containment
         return validate_span_containment(g_wave.d_idx, g_wave.d_price, new_last_idx, new_last_price, !g_wave.x_less_than_a);
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Update wave structure with new dynamic last point                 |
//+------------------------------------------------------------------+
void update_wave_last_point(pattern_type_enum ptype, int new_idx, double new_price) {
   switch(ptype) {
      case XAB: g_wave.b_idx = new_idx; g_wave.b_price = new_price; break;
      case XABC: g_wave.c_idx = new_idx; g_wave.c_price = new_price; break;
      case XABCD: g_wave.d_idx = new_idx; g_wave.d_price = new_price; break;
      case XABCDE: g_wave.e_idx = new_idx; g_wave.e_price = new_price; break;
      case XABCDEF: g_wave.f_idx = new_idx; g_wave.f_price = new_price; break;
   }
}

//+------------------------------------------------------------------+
//| Draw label for dynamic last point                                 |
//+------------------------------------------------------------------+
void draw_dynamic_last_point_label(string id, int idx, double price, int count) {
   string objname = Prefix + "dyn_last_" + id;
   string label_text = "L" + (string)count;
   
   ObjectCreate(0, objname, OBJ_TEXT, 0, iTime(_Symbol, _Period, idx), price);
   ObjectSetString(0, objname, OBJPROP_TEXT, label_text);
   ObjectSetString(0, objname, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, objname, OBJPROP_FONTSIZE, label_font_size);
   ObjectSetInteger(0, objname, OBJPROP_COLOR, dynamic_last_point_color);
   
   // Position below for bullish (last point is LOW), above for bearish (last point is HIGH)
   if(g_wave.is_bullish)
      ObjectSetInteger(0, objname, OBJPROP_ANCHOR, ANCHOR_UPPER);
   else
      ObjectSetInteger(0, objname, OBJPROP_ANCHOR, ANCHOR_LOWER);
}

//+------------------------------------------------------------------+
//| Draw pattern lines                                                |
//+------------------------------------------------------------------+
void draw_pattern(pattern_type_enum ptype) {
   draw_line("px", g_wave.p_idx, g_wave.p_price, g_wave.x_idx, g_wave.x_price, px_color);
   draw_line("xa", g_wave.x_idx, g_wave.x_price, g_wave.a_idx, g_wave.a_price, xa_color);
   draw_line("ab", g_wave.a_idx, g_wave.a_price, g_wave.b_idx, g_wave.b_price, ab_color);
   
   if(ptype >= XABC)
      draw_line("bc", g_wave.b_idx, g_wave.b_price, g_wave.c_idx, g_wave.c_price, bc_color);
   if(ptype >= XABCD)
      draw_line("cd", g_wave.c_idx, g_wave.c_price, g_wave.d_idx, g_wave.d_price, cd_color);
   if(ptype >= XABCDE)
      draw_line("de", g_wave.d_idx, g_wave.d_price, g_wave.e_idx, g_wave.e_price, de_color);
   if(ptype >= XABCDEF)
      draw_line("ef", g_wave.e_idx, g_wave.e_price, g_wave.f_idx, g_wave.f_price, ef_color);
}

//+------------------------------------------------------------------+
//| Draw channels                                                     |
//+------------------------------------------------------------------+
void draw_channels(pattern_type_enum ptype) {
   int last_idx;
   switch(ptype) {
      case XAB: last_idx = g_wave.b_idx; break;
      case XABC: last_idx = g_wave.c_idx; break;
      case XABCD: last_idx = g_wave.d_idx; break;
      case XABCDE: last_idx = g_wave.e_idx; break;
      case XABCDEF: last_idx = g_wave.f_idx; break;
      default: last_idx = g_wave.b_idx;
   }

   int ext_idx = last_idx - channel_extension_bars;
   int bars_x_b = g_wave.x_idx - g_wave.b_idx;
   if(bars_x_b <= 0) return;
   
   double xb_slope = (g_wave.b_price - g_wave.x_price) / bars_x_b;
   double a_slope = get_a_channel_slope(xb_slope, g_wave.x_less_than_a);
   
   int bars_to_ext = g_wave.x_idx - ext_idx;
   double xb_end = g_wave.x_price + bars_to_ext * xb_slope;
   double xb_upper_width = MathAbs(g_wave.x_price) * (g_wave.x_less_than_a ? xb_upper_width_pct : xb_lower_width_pct) * 0.01;
   double xb_lower_width = MathAbs(g_wave.x_price) * (g_wave.x_less_than_a ? xb_lower_width_pct : xb_upper_width_pct) * 0.01;

   draw_channel_line("xb_c", g_wave.x_idx, g_wave.x_price, ext_idx, xb_end, xb_channel_color, 2, STYLE_SOLID);
   draw_channel_line("xb_u", g_wave.x_idx, g_wave.x_price + xb_upper_width, ext_idx, xb_end + xb_upper_width, xb_channel_color, 1, STYLE_DOT);
   draw_channel_line("xb_l", g_wave.x_idx, g_wave.x_price - xb_lower_width, ext_idx, xb_end - xb_lower_width, xb_channel_color, 1, STYLE_DOT);
   
   int bars_a_ext = g_wave.a_idx - ext_idx;
   double a_end = g_wave.a_price + bars_a_ext * a_slope;
   double a_upper_width = MathAbs(g_wave.a_price) * (g_wave.x_less_than_a ? a_upper_width_pct : a_lower_width_pct) * 0.01;
   double a_lower_width = MathAbs(g_wave.a_price) * (g_wave.x_less_than_a ? a_lower_width_pct : a_upper_width_pct) * 0.01;

   draw_channel_line("a_c", g_wave.a_idx, g_wave.a_price, ext_idx, a_end, a_channel_color, 2, STYLE_SOLID);
   draw_channel_line("a_u", g_wave.a_idx, g_wave.a_price + a_upper_width, ext_idx, a_end + a_upper_width, a_channel_color, 1, STYLE_DOT);
   draw_channel_line("a_l", g_wave.a_idx, g_wave.a_price - a_lower_width, ext_idx, a_end - a_lower_width, a_channel_color, 1, STYLE_DOT);
}

//+------------------------------------------------------------------+
//| Draw all labels                                                   |
//+------------------------------------------------------------------+
void draw_all_labels(pattern_type_enum ptype) {
   int x_pos = g_wave.x_less_than_a ? -1 : 1;
   draw_label("X", g_wave.x_idx, x_pos);
   draw_label("A", g_wave.a_idx, -x_pos);
   draw_label("B", g_wave.b_idx, x_pos);
   if(ptype >= XABC) draw_label("C", g_wave.c_idx, -x_pos);
   if(ptype >= XABCD) draw_label("D", g_wave.d_idx, x_pos);
   if(ptype >= XABCDE) draw_label("E", g_wave.e_idx, -x_pos);
   if(ptype >= XABCDEF) draw_label("F", g_wave.f_idx, x_pos);
}

//+------------------------------------------------------------------+
//| Helper: Draw line (pattern lines)                                 |
//+------------------------------------------------------------------+
void draw_line(string name, int idx1, double p1, int idx2, double p2, color clr) {
   int max_bars = Bars(_Symbol, _Period) - 1;
   if(idx1 < 0) idx1 = 0; if(idx1 > max_bars) return;
   
   string salt = (string)MathRand() + (string)MathRand();
   string objname = Prefix + name + salt;
   
   datetime t1 = iTime(_Symbol, _Period, idx1);
   datetime t2 = (idx2 >= 0) ? iTime(_Symbol, _Period, MathMin(idx2, max_bars)) : 
                              iTime(_Symbol, _Period, 0) + MathAbs(idx2) * PeriodSeconds();
   
   ObjectCreate(0, objname, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, objname, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objname, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, objname, OBJPROP_RAY_RIGHT, false);
}

//+------------------------------------------------------------------+
//| Helper: Draw line for golden line (with x_idx for unique naming)  |
//+------------------------------------------------------------------+
void draw_golden_line_obj(string name, int x_idx, int idx1, double p1, int idx2, double p2, color clr) {
   int max_bars = Bars(_Symbol, _Period) - 1;
   if(idx1 < 0) idx1 = 0; 
   if(idx1 > max_bars) return;
   
   string salt = (string)MathRand() + (string)MathRand();
   string objname = Prefix + name + (string)x_idx + salt;
   
   datetime t1 = iTime(_Symbol, _Period, idx1);
   datetime t2;
   if(idx2 >= 0)
      t2 = iTime(_Symbol, _Period, MathMin(idx2, max_bars));
   else
      t2 = iTime(_Symbol, _Period, 0) + MathAbs(idx2) * PeriodSeconds();
   
   ObjectCreate(0, objname, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, objname, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objname, OBJPROP_WIDTH, 3);  // Thicker line for visibility
   ObjectSetInteger(0, objname, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, objname, OBJPROP_STYLE, STYLE_SOLID);
   
   Print("DRAW_GOLDEN_LINE: Created ", objname, " from idx=", idx1, " p1=", DoubleToString(p1,5), 
         " to idx2=", idx2, " p2=", DoubleToString(p2,5), " color=", clr);
}

//+------------------------------------------------------------------+
//| Helper: Draw channel line                                         |
//+------------------------------------------------------------------+
void draw_channel_line(string name, int idx1, double p1, int idx2, double p2, 
                       color clr, int width, ENUM_LINE_STYLE style) {
   int max_bars = Bars(_Symbol, _Period) - 1;
   if(idx1 < 0) idx1 = 0; if(idx1 > max_bars) return;
   
   string salt = (string)MathRand() + (string)MathRand();
   string objname = Prefix + name + salt;
   
   datetime t1 = iTime(_Symbol, _Period, idx1);
   datetime t2 = (idx2 >= 0) ? iTime(_Symbol, _Period, MathMin(idx2, max_bars)) :
                              iTime(_Symbol, _Period, 0) + MathAbs(idx2) * PeriodSeconds();
   
   ObjectCreate(0, objname, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, objname, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objname, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, objname, OBJPROP_STYLE, style);
   ObjectSetInteger(0, objname, OBJPROP_RAY_RIGHT, false);
}

//+------------------------------------------------------------------+
//| Helper: Draw label                                                |
//+------------------------------------------------------------------+
void draw_label(string txt, int idx, int vert_pos) {
   if(idx < 0 || idx >= ArraySize(mrate)) return;
   double price = (vert_pos == 1) ? mrate[idx].high : mrate[idx].low;
   string objname = Prefix + txt + (string)MathRand();
   
   ObjectCreate(0, objname, OBJ_TEXT, 0, iTime(_Symbol, _Period, idx), price);
   ObjectSetString(0, objname, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, objname, OBJPROP_FONTSIZE, label_font_size);
   ObjectSetInteger(0, objname, OBJPROP_COLOR, label_font_color);
   if(vert_pos == 1) ObjectSetInteger(0, objname, OBJPROP_ANCHOR, ANCHOR_LOWER);
}

//+------------------------------------------------------------------+
//| Helper: Draw arrow                                                |
//+------------------------------------------------------------------+
void draw_arrow(string type, int idx, double price) {
   string objname = Prefix + type + (string)MathRand() + (string)MathRand();
   ObjectCreate(0, objname, type == "buy" ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, 
                iTime(_Symbol, _Period, idx), price);
   ObjectSetInteger(0, objname, OBJPROP_COLOR, type == "buy" ? arrow_buy_color : arrow_sell_color);
   ObjectSetInteger(0, objname, OBJPROP_WIDTH, arrow_size);
   if(type == "sell") ObjectSetInteger(0, objname, OBJPROP_ANCHOR, ANCHOR_LOWER);
}

//+------------------------------------------------------------------+
//| Helper: Append to array                                           |
//+------------------------------------------------------------------+
void append_double(double& arr[], double val) {
   ArrayResize(arr, ArraySize(arr) + 1);
   arr[ArraySize(arr) - 1] = val;
}
void append_int(int& arr[], int val) {
   ArrayResize(arr, ArraySize(arr) + 1);
   arr[ArraySize(arr) - 1] = val;
}

//+------------------------------------------------------------------+
//| Tick speed filter                                                 |
//+------------------------------------------------------------------+
bool tick_speed_filter(int idx1, int idx2) {
   int seconds1 = int(iTime(_Symbol, _Period, idx2) - iTime(_Symbol, _Period, idx1));
   int bars1 = idx1 - idx2;
   
   if(bars1 <= 0) return true;
   if(seconds1 / bars1 < tick_min_speed)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Divergence filter                                                 |
//+------------------------------------------------------------------+
bool divergence_filter(int idx1, int idx2, int idx3, int _direction) {
   if(divergence_type == None_Divergence)
      return true;
   
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
//| GOLDEN LINE - UPTREND (X < A)                                     |
//| Exact algorithm from AbdullahProjSourceCode.mq5 phase_two()       |
//| Signal type alternates: XABC=SELL, XABCD=BUY, XABCDE=SELL, etc.  |
//+------------------------------------------------------------------+
void golden_line_uptrend(pattern_type_enum ptype) {
   // For X < A: B=LOW, C=HIGH, D=LOW, E=HIGH, F=LOW
   // XAB   (last=B=LOW):  use HIGHs (opposite!), BUY signal
   // XABC  (last=C=HIGH): use LOWs (opposite!), SELL signal
   // XABCD (last=D=LOW):  use HIGHs (opposite!), BUY signal
   // XABCDE(last=E=HIGH): use LOWs (opposite!), SELL signal
   // XABCDEF(last=F=LOW): use HIGHs (opposite!), BUY signal
   bool last_is_high = (ptype == XABC || ptype == XABCDE);
   bool signal_is_sell = last_is_high;  // SELL for HIGH last points

//=================================================================
   // SETUP based on pattern type - with conditional slope selection
   //=================================================================
   double last_price, sp_price, z_price;
   int last_idx, sp_idx, z_idx;
   double step_slope;
   double SlopeArray[];
   int bars_slope;
   double final_diff_for_fg = 0;  // For XABCDE special FG calculation

   if(ptype == XAB) {
      // Simple: XB slope, SP = A
      last_price = g_wave.b_price; last_idx = g_wave.b_idx;
      sp_price = g_wave.a_price; sp_idx = g_wave.a_idx;

      bars_slope = g_wave.x_idx - g_wave.b_idx;
      if(bars_slope <= 0) return;
      step_slope = (g_wave.b_price - g_wave.x_price) / bars_slope;

      ArrayResize(SlopeArray, bars_slope + 1);
      for(int i = 0; i <= bars_slope; i++)
         SlopeArray[i] = g_wave.x_price + i * step_slope;

      int bars_to_a = g_wave.x_idx - g_wave.a_idx;
      if(bars_to_a < 0 || bars_to_a > bars_slope) return;
      z_price = SlopeArray[bars_to_a];
      z_idx = g_wave.a_idx;
   }
   else if(ptype == XABC) {
      // Simple: AC slope, SP = B
      last_price = g_wave.c_price; last_idx = g_wave.c_idx;
      sp_price = g_wave.b_price; sp_idx = g_wave.b_idx;

      bars_slope = g_wave.a_idx - g_wave.c_idx;
      if(bars_slope <= 0) return;
      step_slope = (g_wave.c_price - g_wave.a_price) / bars_slope;
      
      ArrayResize(SlopeArray, bars_slope + 1);
      for(int i = 0; i <= bars_slope; i++)
         SlopeArray[i] = g_wave.a_price + i * step_slope;
      
      int bars_to_b = g_wave.a_idx - g_wave.b_idx;
      if(bars_to_b < 0 || bars_to_b > bars_slope) return;
      z_price = SlopeArray[bars_to_b];
      z_idx = g_wave.b_idx;
   }
   else if(ptype == XABCD) {
      // Complex: Create BOTH XD and BD arrays, conditional selection
      last_price = g_wave.d_price; last_idx = g_wave.d_idx;
      sp_price = g_wave.c_price; sp_idx = g_wave.c_idx;
      
      // XD array
      int bars_x_d = g_wave.x_idx - g_wave.d_idx;
      if(bars_x_d <= 0) return;
      double StepXD = (g_wave.d_price - g_wave.x_price) / bars_x_d;
      double XDArray[];
      ArrayResize(XDArray, bars_x_d + 1);
      for(int i = 0; i <= bars_x_d; i++)
         XDArray[i] = g_wave.x_price + i * StepXD;
      
      // BD array
      int bars_b_d = g_wave.b_idx - g_wave.d_idx;
      if(bars_b_d <= 0) return;
      double StepBD = (g_wave.d_price - g_wave.b_price) / bars_b_d;
      double BDArray[];
      ArrayResize(BDArray, bars_b_d + 1);
      for(int i = 0; i <= bars_b_d; i++)
         BDArray[i] = g_wave.b_price + i * StepBD;
      
      // Check if B is lower than XD line at B's position
      int b_offset_in_xd = g_wave.x_idx - g_wave.b_idx;
      bool b_is_lower = (g_wave.b_price < XDArray[b_offset_in_xd]);

      // Select slope based on condition
      if(b_is_lower) {
         bars_slope = bars_x_d;
         step_slope = StepXD;
         ArrayResize(SlopeArray, bars_slope + 1);
         ArrayCopy(SlopeArray, XDArray);
         int c_offset = g_wave.x_idx - g_wave.c_idx;
         if(c_offset < 0 || c_offset >= ArraySize(SlopeArray)) return;
         z_price = XDArray[c_offset];
      } else {
         bars_slope = bars_b_d;
         step_slope = StepBD;
         ArrayResize(SlopeArray, bars_slope + 1);
         ArrayCopy(SlopeArray, BDArray);
         int c_offset = g_wave.b_idx - g_wave.c_idx;
         if(c_offset < 0 || c_offset >= ArraySize(SlopeArray)) return;
         z_price = BDArray[c_offset];
      }
      z_idx = g_wave.c_idx;
   }
   else if(ptype == XABCDE) {
      // Complex: Create BOTH AE and CE arrays, conditional selection with SP possibly being D or B
      last_price = g_wave.e_price; last_idx = g_wave.e_idx;
      
      // AE array
      int bars_a_e = g_wave.a_idx - g_wave.e_idx;
      if(bars_a_e <= 0) return;
      double StepAE = (g_wave.e_price - g_wave.a_price) / bars_a_e;
      double AEArray[];
      ArrayResize(AEArray, bars_a_e + 1);
      for(int i = 0; i <= bars_a_e; i++)
         AEArray[i] = g_wave.a_price + i * StepAE;
      
      // CE array
      int bars_c_e = g_wave.c_idx - g_wave.e_idx;
      if(bars_c_e <= 0) return;
      double StepCE = (g_wave.e_price - g_wave.c_price) / bars_c_e;
      double CEArray[];
      ArrayResize(CEArray, bars_c_e + 1);
      for(int i = 0; i <= bars_c_e; i++)
         CEArray[i] = g_wave.c_price + i * StepCE;
      
      // Check if C is higher than AE line
      int c_offset_in_ae = g_wave.a_idx - g_wave.c_idx;
      bool c_is_higher = (g_wave.c_price > AEArray[c_offset_in_ae]);
      
      // Calculate distances from AE for D and B
      int d_offset_in_ae = g_wave.a_idx - g_wave.d_idx;
      int b_offset_in_ae = g_wave.a_idx - g_wave.b_idx;
      double d_diff = g_wave.d_price - AEArray[d_offset_in_ae];
      double b_diff = g_wave.b_price - AEArray[b_offset_in_ae];
      
      double final_diff;
      if(c_is_higher) {
         // Use AE slope, SP is D or B based on which is farther from AE
         if(d_diff > b_diff) {
            z_price = AEArray[d_offset_in_ae];
            z_idx = g_wave.d_idx;
            sp_price = g_wave.d_price;
            sp_idx = g_wave.d_idx;
            final_diff = g_wave.d_price - z_price;
         } else {
            z_price = AEArray[b_offset_in_ae];
            z_idx = g_wave.b_idx;
            sp_price = g_wave.b_price;
            sp_idx = g_wave.b_idx;
            final_diff = b_diff;
         }
         bars_slope = bars_a_e;
         step_slope = StepAE;
         ArrayResize(SlopeArray, bars_slope + 1);
         ArrayCopy(SlopeArray, AEArray);
      } else {
         // Use CE slope, SP is D
         int d_offset_in_ce = g_wave.c_idx - g_wave.d_idx;
         z_price = CEArray[d_offset_in_ce];
         z_idx = g_wave.d_idx;
         sp_price = g_wave.d_price;
         sp_idx = g_wave.d_idx;
         final_diff = d_diff;
         bars_slope = bars_c_e;
         step_slope = StepCE;
         ArrayResize(SlopeArray, bars_slope + 1);
         ArrayCopy(SlopeArray, CEArray);
      }
      // Store final_diff for FG calculation (XABCDE specific)
      final_diff_for_fg = final_diff;
   }
   else if(ptype == XABCDEF) {
      // Extending pattern: XF/BF/DF conditional (following XABCD pattern)
      last_price = g_wave.f_price; last_idx = g_wave.f_idx;
      sp_price = g_wave.e_price; sp_idx = g_wave.e_idx;
      
      // XF array
      int bars_x_f = g_wave.x_idx - g_wave.f_idx;
      if(bars_x_f <= 0) return;
      double StepXF = (g_wave.f_price - g_wave.x_price) / bars_x_f;
      double XFArray[];
      ArrayResize(XFArray, bars_x_f + 1);
      for(int i = 0; i <= bars_x_f; i++)
         XFArray[i] = g_wave.x_price + i * StepXF;
      
      // DF array
      int bars_d_f = g_wave.d_idx - g_wave.f_idx;
      if(bars_d_f <= 0) return;
      double StepDF = (g_wave.f_price - g_wave.d_price) / bars_d_f;
      double DFArray[];
      ArrayResize(DFArray, bars_d_f + 1);
      for(int i = 0; i <= bars_d_f; i++)
         DFArray[i] = g_wave.d_price + i * StepDF;
      
      // Check if D is lower than XF line at D's position
      int d_offset_in_xf = g_wave.x_idx - g_wave.d_idx;
      bool d_is_lower = (g_wave.d_price < XFArray[d_offset_in_xf]);

      if(d_is_lower) {
         bars_slope = bars_x_f;
         step_slope = StepXF;
         ArrayResize(SlopeArray, bars_slope + 1);
         ArrayCopy(SlopeArray, XFArray);
         int e_offset = g_wave.x_idx - g_wave.e_idx;
         if(e_offset < 0 || e_offset >= ArraySize(SlopeArray)) return;
         z_price = XFArray[e_offset];
      } else {
         bars_slope = bars_d_f;
         step_slope = StepDF;
         ArrayResize(SlopeArray, bars_slope + 1);
         ArrayCopy(SlopeArray, DFArray);
         int e_offset = g_wave.d_idx - g_wave.e_idx;
         if(e_offset < 0 || e_offset >= ArraySize(SlopeArray)) return;
         z_price = DFArray[e_offset];
      }
      z_idx = g_wave.e_idx;
   }
   else return;

   if(sp_idx <= last_idx) return;

   //=================================================================
   // FG Separator Line
   //=================================================================
   bool separate_found = false;
   int idxs_above_fg[];
   int idxs_below_fg[];
   double FGArray[];
   double fg_start_price;
   int fg_start_idx;
   int bars_fg;
   // Use default formula if not set by XABCDE
   // For XABC/XABCD, final_diff_for_fg = (sp_price - z_price) - can be negative!
   if(final_diff_for_fg == 0)
      final_diff_for_fg = sp_price - z_price;

   int total_iterations = (int)((100 - f_percentage) / fg_increasing_percentage) + 2;
   for(int q = 0; q <= total_iterations; q++) {
      ArrayFree(idxs_above_fg);
      ArrayFree(idxs_below_fg);
      ArrayFree(FGArray);

      double p_to_check = f_percentage + q * fg_increasing_percentage;
      if(p_to_check > 100) p_to_check = 100;

      // FG line position - moves from Z toward SP
      fg_start_price = z_price + final_diff_for_fg * p_to_check * 0.01;
      fg_start_idx = z_idx;

      bars_fg = fg_start_idx - last_idx;
      if(bars_fg <= 0) continue;

      ArrayResize(FGArray, bars_fg + 1);
      for(int i = 0; i <= bars_fg; i++) {
         FGArray[i] = fg_start_price + i * step_slope;
      }

      // Check last bar limit - USE OPPOSITE PRICE TYPE per source code!
      // From AbdullahProjSourceCode.mq5:
      // Last=HIGH → use LOW: if(iLow(last_idx) <= FGArray[last]) continue
      // Last=LOW → use HIGH: if(iHigh(last_idx) >= FGArray[last]) continue
      if(last_is_high) {
         double last_bar_limit = iLow(_Symbol, _Period, last_idx);  // HIGH → LOW
         if(last_bar_limit <= FGArray[bars_fg]) continue;
      } else {
         double last_bar_limit = iHigh(_Symbol, _Period, last_idx);  // LOW → HIGH
         if(last_bar_limit >= FGArray[bars_fg]) continue;
      }

      // Divide candles - USE OPPOSITE PRICE TYPE per source code!
      for(int i = 0; i <= sp_idx - last_idx; i++) {
         int candle_idx = sp_idx - i;
         double candle_price;
         if(last_is_high)
            candle_price = iLow(_Symbol, _Period, candle_idx);  // HIGH → LOW
         else
            candle_price = iHigh(_Symbol, _Period, candle_idx);  // LOW → HIGH

         int fg_offset = (i < bars_fg) ? i : bars_fg;
         double fg_value = FGArray[fg_offset];

         if(last_is_high) {
            // Using LOWs: above means LOW > FG
            if(candle_price > fg_value)
               append_int(idxs_above_fg, i);
            else
               append_int(idxs_below_fg, i);
         } else {
            // Using HIGHs: above means HIGH >= FG
            if(candle_price >= fg_value)
               append_int(idxs_above_fg, i);
            else
               append_int(idxs_below_fg, i);
         }
      }

      if(ArraySize(idxs_above_fg) == 0 || ArraySize(idxs_below_fg) == 0)
         continue;

      separate_found = true;
      break;
   }

   if(!separate_found) return;

   //=================================================================
   // Matrix Computation: Find M and N points
   //=================================================================
   int bars_sp_to_last = sp_idx - last_idx;

   for(int j = (int)(first_line_percentage / first_line_decrease_percentage); j >= 0; j--) {
      double current_slope_pct = first_line_percentage - j * first_line_decrease_percentage;
      double slope_per_bar = (sp_price * current_slope_pct * 0.01) / bars_sp_to_last;
      
      double FirstLineArray[];
      ArrayResize(FirstLineArray, bars_sp_to_last + 1);
      for(int i = 0; i <= bars_sp_to_last; i++) {
         // Per source code:
         // Last=HIGH (SELL signal) → FirstLine slopes UP from SP
         // Last=LOW (BUY signal) → FirstLine slopes DOWN from SP
         if(last_is_high)
            FirstLineArray[i] = sp_price + slope_per_bar * i;  // HIGH → slopes UP
         else
            FirstLineArray[i] = sp_price - slope_per_bar * i;  // LOW → slopes DOWN
      }
      
      // Calculate differences - USE OPPOSITE PRICE TYPE per source code!
      // Source: Last=HIGH → use LOW, diff = FirstLine - LOW
      // Source: Last=LOW → use HIGH, diff = HIGH - FirstLine
      double above_diff_array[];
      int above_diff_idx_array[];
      double below_diff_array[];
      int below_diff_idx_array[];
      
      for(int i = 0; i < ArraySize(idxs_above_fg); i++) {
         int offset = idxs_above_fg[i];
         if(offset > bars_sp_to_last) continue;
         int candle_idx = sp_idx - offset;
         double actual_price = last_is_high ? iLow(_Symbol, _Period, candle_idx) : iHigh(_Symbol, _Period, candle_idx);
         double first_line_value = FirstLineArray[offset];
         double diff;
         if(last_is_high)
            diff = first_line_value - actual_price;  // FirstLine - LOW for SELL
         else
            diff = actual_price - first_line_value;  // HIGH - FirstLine for BUY
         
         append_double(above_diff_array, diff);
         append_int(above_diff_idx_array, offset);
      }
      
      for(int i = 0; i < ArraySize(idxs_below_fg); i++) {
         int offset = idxs_below_fg[i];
         if(offset > bars_sp_to_last) continue;
         int candle_idx = sp_idx - offset;
         double actual_price = last_is_high ? iLow(_Symbol, _Period, candle_idx) : iHigh(_Symbol, _Period, candle_idx);
         double first_line_value = FirstLineArray[offset];
         double diff;
         if(last_is_high)
            diff = first_line_value - actual_price;  // FirstLine - LOW for SELL
         else
            diff = actual_price - first_line_value;  // HIGH - FirstLine for BUY
         
         append_double(below_diff_array, diff);
         append_int(below_diff_idx_array, offset);
      }
      
      if(ArraySize(above_diff_array) == 0 || ArraySize(below_diff_array) == 0)
         continue;
      
      double max_above_diff = above_diff_array[ArrayMaximum(above_diff_array)];
      double max_below_diff = below_diff_array[ArrayMaximum(below_diff_array)];
      
      if(max_below_diff < 0 || max_above_diff < 0)
         continue;
      
      // M/N difference validation
      double ref_price = MathAbs(sp_price - last_price);
      if(ref_price < _Point) continue;
      double diff_percentage = MathAbs(max_above_diff - max_below_diff) / ref_price;
      
      if(diff_percentage > maxBelow_maxAbove_diff_percentage * 0.01 && diff_percentage != 1.0)
         continue;
      
      // Get M and N indices and prices - USE OPPOSITE PRICE TYPE!
      int max_above_offset = above_diff_idx_array[ArrayMaximum(above_diff_array)];
      int max_below_offset = below_diff_idx_array[ArrayMaximum(below_diff_array)];
      
      int max_above_idx = sp_idx - max_above_offset;
      int max_below_idx = sp_idx - max_below_offset;
      
      // Use OPPOSITE price type
      double max_above_price = last_is_high ? iLow(_Symbol, _Period, max_above_idx) : iHigh(_Symbol, _Period, max_above_idx);
      double max_below_price = last_is_high ? iLow(_Symbol, _Period, max_below_idx) : iHigh(_Symbol, _Period, max_below_idx);
      
      // Validation per source code
      if(max_below_price > max_above_price) continue;
      
      // For SELL (last_is_high): max_below must be AFTER max_above (max_below_idx <= max_above_idx in bar terms)
      // For BUY (!last_is_high): max_below must be BEFORE max_above (max_below_idx >= max_above_idx in bar terms)
      if(last_is_high) {
         if(max_below_idx <= max_above_idx) continue;  // SELL: below must be after (lower idx = more recent)
      } else {
         if(max_below_idx >= max_above_idx) continue;  // BUY: below must be before (higher idx = older)
      }
      
      // Validate minimum MN segment length
      if(mn_length_percent > 0) {
         int min_mn_bars = (int)(mn_length_percent * 0.01 * bars_sp_to_last);
         if(MathAbs(max_above_idx - max_below_idx) < min_mn_bars)
            continue;
      }
      
      // Calculate step and build MN array
      double step_mn;
      double MNArray[];
      int mn_start_idx;
      double mn_start_price;
      
      // Per source code:
      // last_is_high (SELL): max_below is later (lower idx), MN slopes UP from max_below
      // !last_is_high (BUY): max_above is later (lower idx), MN slopes DOWN from max_above
      if(last_is_high) {
         // SELL setup: golden line slopes UP, start from max_below
         int bars_m_n = max_below_idx - max_above_idx;
         if(bars_m_n <= 0) continue;
         step_mn = (max_above_price - max_below_price) / bars_m_n;
         max_below_price = max_below_price - (max_above_price - max_below_price) * mn_buffer_percent * 0.01;
         mn_start_idx = max_below_idx;
         mn_start_price = max_below_price;
         
         int mn_total_bars = max_below_idx - last_idx + mn_extension_bars;
         if(mn_total_bars <= 0) continue;
         ArrayResize(MNArray, mn_total_bars);
         for(int i = 0; i < mn_total_bars; i++)
            MNArray[i] = max_below_price + i * step_mn;
      } else {
         // BUY setup: golden line slopes DOWN, start from max_above
         int bars_m_n = max_above_idx - max_below_idx;
         if(bars_m_n <= 0) continue;
         step_mn = (max_below_price - max_above_price) / bars_m_n;
         max_above_price = max_above_price + (max_above_price - max_below_price) * mn_buffer_percent * 0.01;
         mn_start_idx = max_above_idx;
         mn_start_price = max_above_price;
         
         int mn_total_bars = max_above_idx - last_idx + mn_extension_bars;
         if(mn_total_bars <= 0) continue;
         ArrayResize(MNArray, mn_total_bars);
         for(int i = 0; i < mn_total_bars; i++)
            MNArray[i] = max_above_price + i * step_mn;
      }
      
      // Build slope extension array
      double SlopeExtArray[];
      int slope_ext_total = bars_slope + mn_extension_bars;
      ArrayResize(SlopeExtArray, slope_ext_total);
      for(int i = 0; i < slope_ext_total; i++) {
         if(i <= bars_slope)
            SlopeExtArray[i] = SlopeArray[i];
         else
            SlopeExtArray[i] = last_price + (i - bars_slope) * step_slope;
      }
      
      // Search for signal - per source code
      // SELL (last_is_high): if(HIGH > ext) break; if(close >= trend) continue; draw "sell"
      // BUY (!last_is_high): if(LOW < ext) break; if(close <= trend) continue; draw "buy"
      for(int i = 1; i < mn_extension_bars; i++) {
         int signal_idx = last_idx - i;
         if(signal_idx < 1) break;
         
         int mn_offset = mn_start_idx - last_idx + i;
         if(mn_offset >= ArraySize(MNArray)) break;
         double trend_price = MNArray[mn_offset];
         
         int slope_ext_offset = bars_slope + i;
         if(slope_ext_offset >= ArraySize(SlopeExtArray)) break;
         double slope_ext_price = SlopeExtArray[slope_ext_offset];
         
         double candle_high = iHigh(_Symbol, _Period, signal_idx);
         double candle_low = iLow(_Symbol, _Period, signal_idx);
         double candle_close = iClose(_Symbol, _Period, signal_idx);
         
         if(signal_is_sell) {
            // SELL: Check if HIGH breaks above slope extension → stop
            double break_price = extension_break_close ? candle_close : candle_high;
            if(break_price > slope_ext_price) break;
            
            // SELL signal when close goes BELOW golden line
            if(candle_close >= trend_price) continue;
            
            draw_arrow("sell", signal_idx, candle_high);
         } else {
            // BUY: Check if LOW breaks below slope extension → stop
            double break_price = extension_break_close ? candle_close : candle_low;
            if(break_price < slope_ext_price) break;
            
            // BUY signal when close goes ABOVE golden line
            if(candle_close <= trend_price) continue;
            
            draw_arrow("buy", signal_idx, candle_low);
         }
         break;
      }
      
      // Draw golden line
      Print("GL_UPTREND: SUCCESS! Drawing golden line mn_start_idx=", mn_start_idx, 
            " mn_start_price=", DoubleToString(mn_start_price, 5), " last_idx=", last_idx);
      if(draw_golden_line) {
         int ext_bars = MathMin(mn_extension_bars, last_idx);
         int mn_end_offset = mn_start_idx - last_idx + ext_bars - 1;
         Print("GL_UPTREND: ext_bars=", ext_bars, " mn_end_offset=", mn_end_offset, " ArraySize=", ArraySize(MNArray));
         if(mn_end_offset > 0 && mn_end_offset < ArraySize(MNArray))
            draw_golden_line_obj("golden", g_wave.x_idx, mn_start_idx, mn_start_price, 
                                 last_idx - ext_bars + 1, MNArray[mn_end_offset], golden_line_color);
         else
            Print("GL_UPTREND: NOT DRAWING - mn_end_offset out of bounds");
      }
      
      // Draw FG separator if enabled
      if(draw_fg_line && ArraySize(FGArray) > 0)
         draw_golden_line_obj("fg", g_wave.x_idx, fg_start_idx, fg_start_price, 
                              last_idx, FGArray[bars_fg], fg_line_color);
      
      return;
   }
   
   // If we get here, we exhausted all slope iterations without finding valid M/N
   Print("GL_UPTREND: FAILED - no valid M/N points found after matrix computation");
   
   // FALLBACK: Draw a simple golden line from SP to last point for debugging
   if(draw_golden_line) {
      Print("GL_UPTREND: Drawing FALLBACK golden line from sp_idx=", sp_idx, " to last_idx=", last_idx);
      draw_golden_line_obj("golden_fallback", g_wave.x_idx, sp_idx, sp_price, 
                           last_idx - mn_extension_bars, last_price, golden_line_color);
   }
}

//+------------------------------------------------------------------+
//| GOLDEN LINE - DOWNTREND (X > A)                                   |
//| Exact algorithm from AbdullahProjSourceCode.mq5 phase_two_bearish()|
//| Signal type alternates: XABC=SELL, XABCD=BUY, XABCDE=SELL, etc.  |
//+------------------------------------------------------------------+
void golden_line_downtrend(pattern_type_enum ptype) {
   // For X > A: B=HIGH, C=LOW, D=HIGH, E=LOW, F=HIGH
   // XAB   (last=B=HIGH): use LOWs (opposite!), SELL signal
   // XABC  (last=C=LOW):  use HIGHs (opposite!), BUY signal
   // XABCD (last=D=HIGH): use LOWs (opposite!), SELL signal
   // XABCDE(last=E=LOW):  use HIGHs (opposite!), BUY signal
   // XABCDEF(last=F=HIGH): use LOWs (opposite!), SELL signal
   bool last_is_high = (ptype == XAB || ptype == XABCD || ptype == XABCDEF);
   bool signal_is_sell = last_is_high;  // For DOWNTREND: HIGH last → SELL, LOW last → BUY

   Print("GL_DOWNTREND: Starting for pattern type ", EnumToString(ptype), " last_is_high=", last_is_high);

   //=================================================================
   // SETUP based on pattern type - with conditional slope selection
   //=================================================================
   double last_price, sp_price, z_price;
   int last_idx, sp_idx, z_idx;
   double step_slope;
   double SlopeArray[];
   int bars_slope;
   double final_diff_for_fg = 0;  // For XABCDE special FG calculation

   if(ptype == XAB) {
      // Simple: XB slope, SP = A
      last_price = g_wave.b_price; last_idx = g_wave.b_idx;
      sp_price = g_wave.a_price; sp_idx = g_wave.a_idx;

      bars_slope = g_wave.x_idx - g_wave.b_idx;
      if(bars_slope <= 0) return;
      step_slope = (g_wave.b_price - g_wave.x_price) / bars_slope;

      ArrayResize(SlopeArray, bars_slope + 1);
      for(int i = 0; i <= bars_slope; i++)
         SlopeArray[i] = g_wave.x_price + i * step_slope;

      int bars_to_a = g_wave.x_idx - g_wave.a_idx;
      if(bars_to_a < 0 || bars_to_a > bars_slope) return;
      z_price = SlopeArray[bars_to_a];
      z_idx = g_wave.a_idx;
   }
   else if(ptype == XABC) {
      // Simple: AC slope, SP = B
      last_price = g_wave.c_price; last_idx = g_wave.c_idx;
      sp_price = g_wave.b_price; sp_idx = g_wave.b_idx;

      bars_slope = g_wave.a_idx - g_wave.c_idx;
      if(bars_slope <= 0) return;
      step_slope = (g_wave.c_price - g_wave.a_price) / bars_slope;
      
      ArrayResize(SlopeArray, bars_slope + 1);
      for(int i = 0; i <= bars_slope; i++)
         SlopeArray[i] = g_wave.a_price + i * step_slope;
      
      int bars_to_b = g_wave.a_idx - g_wave.b_idx;
      if(bars_to_b < 0 || bars_to_b > bars_slope) return;
      z_price = SlopeArray[bars_to_b];
      z_idx = g_wave.b_idx;
   }
   else if(ptype == XABCD) {
      // Complex: Create BOTH XD and BD arrays, conditional selection
      last_price = g_wave.d_price; last_idx = g_wave.d_idx;
      sp_price = g_wave.c_price; sp_idx = g_wave.c_idx;
      
      // XD array
      int bars_x_d = g_wave.x_idx - g_wave.d_idx;
      if(bars_x_d <= 0) return;
      double StepXD = (g_wave.d_price - g_wave.x_price) / bars_x_d;
      double XDArray[];
      ArrayResize(XDArray, bars_x_d + 1);
      for(int i = 0; i <= bars_x_d; i++)
         XDArray[i] = g_wave.x_price + i * StepXD;
      
      // BD array
      int bars_b_d = g_wave.b_idx - g_wave.d_idx;
      if(bars_b_d <= 0) return;
      double StepBD = (g_wave.d_price - g_wave.b_price) / bars_b_d;
      double BDArray[];
      ArrayResize(BDArray, bars_b_d + 1);
      for(int i = 0; i <= bars_b_d; i++)
         BDArray[i] = g_wave.b_price + i * StepBD;
      
      // Check if B is higher than XD line at B's position (opposite of uptrend)
      int b_offset_in_xd = g_wave.x_idx - g_wave.b_idx;
      bool b_is_higher = (g_wave.b_price > XDArray[b_offset_in_xd]);

      // Select slope based on condition
      if(b_is_higher) {
         bars_slope = bars_x_d;
         step_slope = StepXD;
         ArrayResize(SlopeArray, bars_slope + 1);
         ArrayCopy(SlopeArray, XDArray);
         int c_offset = g_wave.x_idx - g_wave.c_idx;
         if(c_offset < 0 || c_offset >= ArraySize(SlopeArray)) return;
         z_price = XDArray[c_offset];
      } else {
         bars_slope = bars_b_d;
         step_slope = StepBD;
         ArrayResize(SlopeArray, bars_slope + 1);
         ArrayCopy(SlopeArray, BDArray);
         int c_offset = g_wave.b_idx - g_wave.c_idx;
         if(c_offset < 0 || c_offset >= ArraySize(SlopeArray)) return;
         z_price = BDArray[c_offset];
      }
      z_idx = g_wave.c_idx;
   }
   else if(ptype == XABCDE) {
      // Complex: Create BOTH AE and CE arrays, conditional selection
      last_price = g_wave.e_price; last_idx = g_wave.e_idx;
      
      // AE array
      int bars_a_e = g_wave.a_idx - g_wave.e_idx;
      if(bars_a_e <= 0) return;
      double StepAE = (g_wave.e_price - g_wave.a_price) / bars_a_e;
      double AEArray[];
      ArrayResize(AEArray, bars_a_e + 1);
      for(int i = 0; i <= bars_a_e; i++)
         AEArray[i] = g_wave.a_price + i * StepAE;
      
      // CE array
      int bars_c_e = g_wave.c_idx - g_wave.e_idx;
      if(bars_c_e <= 0) return;
      double StepCE = (g_wave.e_price - g_wave.c_price) / bars_c_e;
      double CEArray[];
      ArrayResize(CEArray, bars_c_e + 1);
      for(int i = 0; i <= bars_c_e; i++)
         CEArray[i] = g_wave.c_price + i * StepCE;
      
      // Check if C is lower than AE line (opposite of uptrend)
      int c_offset_in_ae = g_wave.a_idx - g_wave.c_idx;
      bool c_is_lower = (g_wave.c_price < AEArray[c_offset_in_ae]);
      
      // Calculate distances from AE for D and B
      int d_offset_in_ae = g_wave.a_idx - g_wave.d_idx;
      int b_offset_in_ae = g_wave.a_idx - g_wave.b_idx;
      double d_diff = AEArray[d_offset_in_ae] - g_wave.d_price;
      double b_diff = AEArray[b_offset_in_ae] - g_wave.b_price;
      
      if(c_is_lower) {
         // Use CE slope, SP is D
         int d_offset_in_ce = g_wave.c_idx - g_wave.d_idx;
         z_price = CEArray[d_offset_in_ce];
         z_idx = g_wave.d_idx;
         sp_price = g_wave.d_price;
         sp_idx = g_wave.d_idx;
         bars_slope = bars_c_e;
         step_slope = StepCE;
         ArrayResize(SlopeArray, bars_slope + 1);
         ArrayCopy(SlopeArray, CEArray);
      } else {
         // Use AE slope, SP is D or B based on which is farther from AE
         if(d_diff > b_diff) {
            z_price = AEArray[d_offset_in_ae];
            z_idx = g_wave.d_idx;
            sp_price = g_wave.d_price;
            sp_idx = g_wave.d_idx;
         } else {
            z_price = AEArray[b_offset_in_ae];
            z_idx = g_wave.b_idx;
            sp_price = g_wave.b_price;
            sp_idx = g_wave.b_idx;
         }
         bars_slope = bars_a_e;
         step_slope = StepAE;
         ArrayResize(SlopeArray, bars_slope + 1);
         ArrayCopy(SlopeArray, AEArray);
      }
      // Store final_diff for FG calculation: unified formula needs (sp_price - z_price)
      final_diff_for_fg = sp_price - z_price;
   }
   else if(ptype == XABCDEF) {
      // Extending pattern: XF/DF conditional (following XABCD pattern)
      last_price = g_wave.f_price; last_idx = g_wave.f_idx;
      sp_price = g_wave.e_price; sp_idx = g_wave.e_idx;
      
      // XF array
      int bars_x_f = g_wave.x_idx - g_wave.f_idx;
      if(bars_x_f <= 0) return;
      double StepXF = (g_wave.f_price - g_wave.x_price) / bars_x_f;
      double XFArray[];
      ArrayResize(XFArray, bars_x_f + 1);
      for(int i = 0; i <= bars_x_f; i++)
         XFArray[i] = g_wave.x_price + i * StepXF;
      
      // DF array
      int bars_d_f = g_wave.d_idx - g_wave.f_idx;
      if(bars_d_f <= 0) return;
      double StepDF = (g_wave.f_price - g_wave.d_price) / bars_d_f;
      double DFArray[];
      ArrayResize(DFArray, bars_d_f + 1);
      for(int i = 0; i <= bars_d_f; i++)
         DFArray[i] = g_wave.d_price + i * StepDF;
      
      // Check if D is higher than XF line at D's position (opposite of uptrend)
      int d_offset_in_xf = g_wave.x_idx - g_wave.d_idx;
      bool d_is_higher = (g_wave.d_price > XFArray[d_offset_in_xf]);

      if(d_is_higher) {
         bars_slope = bars_x_f;
         step_slope = StepXF;
         ArrayResize(SlopeArray, bars_slope + 1);
         ArrayCopy(SlopeArray, XFArray);
         int e_offset = g_wave.x_idx - g_wave.e_idx;
         if(e_offset < 0 || e_offset >= ArraySize(SlopeArray)) return;
         z_price = XFArray[e_offset];
      } else {
         bars_slope = bars_d_f;
         step_slope = StepDF;
         ArrayResize(SlopeArray, bars_slope + 1);
         ArrayCopy(SlopeArray, DFArray);
         int e_offset = g_wave.d_idx - g_wave.e_idx;
         if(e_offset < 0 || e_offset >= ArraySize(SlopeArray)) return;
         z_price = DFArray[e_offset];
      }
      z_idx = g_wave.e_idx;
   }
   else return;
   
   if(sp_idx <= last_idx) return;
   
   //=================================================================
   // FG Separator Line
   //=================================================================
   bool separate_found = false;
   int idxs_above_fg[];
   int idxs_below_fg[];
   double FGArray[];
   double fg_start_price;
   int fg_start_idx;
   int bars_fg;
   // Use default formula if not set by XABCDE
   // For XABC/XABCD, final_diff_for_fg = (sp_price - z_price) - can be negative!
   if(final_diff_for_fg == 0)
      final_diff_for_fg = sp_price - z_price;
   
   int total_iterations = (int)((100 - f_percentage) / fg_increasing_percentage) + 2;
   for(int q = 0; q <= total_iterations; q++) {
      ArrayFree(idxs_above_fg);
      ArrayFree(idxs_below_fg);
      ArrayFree(FGArray);
      
      double p_to_check = f_percentage + q * fg_increasing_percentage;
      if(p_to_check > 100) p_to_check = 100;
      
      // FG line position - moves from Z toward SP
      fg_start_price = z_price + final_diff_for_fg * p_to_check * 0.01;
      fg_start_idx = z_idx;
      
      bars_fg = fg_start_idx - last_idx;
      if(bars_fg <= 0) continue;
      
      ArrayResize(FGArray, bars_fg + 1);
      for(int i = 0; i <= bars_fg; i++) {
         FGArray[i] = fg_start_price + i * step_slope;
      }
      
      // Check last bar limit - USE OPPOSITE PRICE TYPE per source code!
      // From AbdullahProjSourceCode.mq5:
      // Last=HIGH → use LOW: if(iLow(last_idx) <= FGArray[last]) continue
      // Last=LOW → use HIGH: if(iHigh(last_idx) >= FGArray[last]) continue
      if(last_is_high) {
         double last_bar_limit = iLow(_Symbol, _Period, last_idx);  // HIGH → LOW
         if(last_bar_limit <= FGArray[bars_fg]) continue;
      } else {
         double last_bar_limit = iHigh(_Symbol, _Period, last_idx);  // LOW → HIGH
         if(last_bar_limit >= FGArray[bars_fg]) continue;
      }
      
      // Divide candles - USE OPPOSITE PRICE TYPE per source code!
      for(int i = 0; i <= sp_idx - last_idx; i++) {
         int candle_idx = sp_idx - i;
         double candle_price;
         if(last_is_high)
            candle_price = iLow(_Symbol, _Period, candle_idx);  // HIGH → LOW
         else
            candle_price = iHigh(_Symbol, _Period, candle_idx);  // LOW → HIGH
         
         int fg_offset = (i < bars_fg) ? i : bars_fg;
         double fg_value = FGArray[fg_offset];
         
         if(last_is_high) {
            // Using LOWs: above means LOW > FG
            if(candle_price > fg_value)
               append_int(idxs_above_fg, i);
            else
               append_int(idxs_below_fg, i);
         } else {
            // Using HIGHs: above means HIGH >= FG
            if(candle_price >= fg_value)
               append_int(idxs_above_fg, i);
            else
               append_int(idxs_below_fg, i);
         }
      }
      
      if(ArraySize(idxs_above_fg) == 0 || ArraySize(idxs_below_fg) == 0)
         continue;
      
      separate_found = true;
      break;
   }
   
   if(!separate_found) return;
   
   //=================================================================
   // Matrix Computation: Find M and N points
   //=================================================================
   int bars_sp_to_last = sp_idx - last_idx;
   
   for(int j = (int)(first_line_percentage / first_line_decrease_percentage); j >= 0; j--) {
      double current_slope_pct = first_line_percentage - j * first_line_decrease_percentage;
      double slope_per_bar = (sp_price * current_slope_pct * 0.01) / bars_sp_to_last;
      
      double FirstLineArray[];
      ArrayResize(FirstLineArray, bars_sp_to_last + 1);
      for(int i = 0; i <= bars_sp_to_last; i++) {
         // Per source code:
         // Last=HIGH (SELL signal) → FirstLine slopes UP from SP
         // Last=LOW (BUY signal) → FirstLine slopes DOWN from SP
         if(last_is_high)
            FirstLineArray[i] = sp_price + slope_per_bar * i;  // HIGH → slopes UP
         else
            FirstLineArray[i] = sp_price - slope_per_bar * i;  // LOW → slopes DOWN
      }
      
      // Calculate differences - USE OPPOSITE PRICE TYPE per source code!
      // Source: Last=HIGH → use LOW, diff = FirstLine - LOW
      // Source: Last=LOW → use HIGH, diff = HIGH - FirstLine
      double above_diff_array[];
      int above_diff_idx_array[];
      double below_diff_array[];
      int below_diff_idx_array[];
      
      for(int i = 0; i < ArraySize(idxs_above_fg); i++) {
         int offset = idxs_above_fg[i];
         if(offset > bars_sp_to_last) continue;
         int candle_idx = sp_idx - offset;
         double actual_price = last_is_high ? iLow(_Symbol, _Period, candle_idx) : iHigh(_Symbol, _Period, candle_idx);
         double first_line_value = FirstLineArray[offset];
         double diff;
         if(last_is_high)
            diff = first_line_value - actual_price;  // FirstLine - LOW for SELL
         else
            diff = actual_price - first_line_value;  // HIGH - FirstLine for BUY
         
         append_double(above_diff_array, diff);
         append_int(above_diff_idx_array, offset);
      }
      
      for(int i = 0; i < ArraySize(idxs_below_fg); i++) {
         int offset = idxs_below_fg[i];
         if(offset > bars_sp_to_last) continue;
         int candle_idx = sp_idx - offset;
         double actual_price = last_is_high ? iLow(_Symbol, _Period, candle_idx) : iHigh(_Symbol, _Period, candle_idx);
         double first_line_value = FirstLineArray[offset];
         double diff;
         if(last_is_high)
            diff = first_line_value - actual_price;  // FirstLine - LOW for SELL
         else
            diff = actual_price - first_line_value;  // HIGH - FirstLine for BUY
         
         append_double(below_diff_array, diff);
         append_int(below_diff_idx_array, offset);
      }
      
      if(ArraySize(above_diff_array) == 0 || ArraySize(below_diff_array) == 0)
         continue;
      
      double max_above_diff = above_diff_array[ArrayMaximum(above_diff_array)];
      double max_below_diff = below_diff_array[ArrayMaximum(below_diff_array)];
      
      if(max_below_diff < 0 || max_above_diff < 0)
         continue;
      
      // M/N difference validation
      double ref_price = MathAbs(sp_price - last_price);
      if(ref_price < _Point) continue;
      double diff_percentage = MathAbs(max_above_diff - max_below_diff) / ref_price;
      
      if(diff_percentage > maxBelow_maxAbove_diff_percentage * 0.01 && diff_percentage != 1.0)
         continue;
      
      // Get M and N indices and prices - USE OPPOSITE PRICE TYPE!
      int max_above_offset = above_diff_idx_array[ArrayMaximum(above_diff_array)];
      int max_below_offset = below_diff_idx_array[ArrayMaximum(below_diff_array)];
      
      int max_above_idx = sp_idx - max_above_offset;
      int max_below_idx = sp_idx - max_below_offset;
      
      // Use OPPOSITE price type
      double max_above_price = last_is_high ? iLow(_Symbol, _Period, max_above_idx) : iHigh(_Symbol, _Period, max_above_idx);
      double max_below_price = last_is_high ? iLow(_Symbol, _Period, max_below_idx) : iHigh(_Symbol, _Period, max_below_idx);
      
      // Validation per source code
      if(max_below_price > max_above_price) continue;
      
      // For SELL (last_is_high): max_below must be AFTER max_above (max_below_idx <= max_above_idx in bar terms)
      // For BUY (!last_is_high): max_below must be BEFORE max_above (max_below_idx >= max_above_idx in bar terms)
      if(last_is_high) {
         if(max_below_idx <= max_above_idx) continue;  // SELL: below must be after (lower idx = more recent)
      } else {
         if(max_below_idx >= max_above_idx) continue;  // BUY: below must be before (higher idx = older)
      }
      
      // Validate minimum MN segment length
      if(mn_length_percent > 0) {
         int min_mn_bars = (int)(mn_length_percent * 0.01 * bars_sp_to_last);
         if(MathAbs(max_above_idx - max_below_idx) < min_mn_bars)
            continue;
      }
      
      // Calculate step and build MN array
      double step_mn;
      double MNArray[];
      int mn_start_idx;
      double mn_start_price;
      
      // Per source code:
      // last_is_high (SELL): max_below is later (lower idx), MN slopes UP from max_below
      // !last_is_high (BUY): max_above is later (lower idx), MN slopes DOWN from max_above
      if(last_is_high) {
         // SELL setup: golden line slopes UP, start from max_below
         int bars_m_n = max_below_idx - max_above_idx;
         if(bars_m_n <= 0) continue;
         step_mn = (max_above_price - max_below_price) / bars_m_n;
         max_below_price = max_below_price - (max_above_price - max_below_price) * mn_buffer_percent * 0.01;
         mn_start_idx = max_below_idx;
         mn_start_price = max_below_price;
         
         int mn_total_bars = max_below_idx - last_idx + mn_extension_bars;
         if(mn_total_bars <= 0) continue;
         ArrayResize(MNArray, mn_total_bars);
         for(int i = 0; i < mn_total_bars; i++)
            MNArray[i] = max_below_price + i * step_mn;
      } else {
         // BUY setup: golden line slopes DOWN, start from max_above
         int bars_m_n = max_above_idx - max_below_idx;
         if(bars_m_n <= 0) continue;
         step_mn = (max_below_price - max_above_price) / bars_m_n;
         max_above_price = max_above_price + (max_above_price - max_below_price) * mn_buffer_percent * 0.01;
         mn_start_idx = max_above_idx;
         mn_start_price = max_above_price;
         
         int mn_total_bars = max_above_idx - last_idx + mn_extension_bars;
         if(mn_total_bars <= 0) continue;
         ArrayResize(MNArray, mn_total_bars);
         for(int i = 0; i < mn_total_bars; i++)
            MNArray[i] = max_above_price + i * step_mn;
      }
      
      // Build slope extension array
      double SlopeExtArray[];
      int slope_ext_total = bars_slope + mn_extension_bars;
      ArrayResize(SlopeExtArray, slope_ext_total);
      for(int i = 0; i < slope_ext_total; i++) {
         if(i <= bars_slope)
            SlopeExtArray[i] = SlopeArray[i];
         else
            SlopeExtArray[i] = last_price + (i - bars_slope) * step_slope;
      }
      
      // Search for signal - per source code
      // SELL (last_is_high): if(HIGH > ext) break; if(close >= trend) continue; draw "sell"
      // BUY (!last_is_high): if(LOW < ext) break; if(close <= trend) continue; draw "buy"
      for(int i = 1; i < mn_extension_bars; i++) {
         int signal_idx = last_idx - i;
         if(signal_idx < 1) break;
         
         int mn_offset = mn_start_idx - last_idx + i;
         if(mn_offset >= ArraySize(MNArray)) break;
         double trend_price = MNArray[mn_offset];
         
         int slope_ext_offset = bars_slope + i;
         if(slope_ext_offset >= ArraySize(SlopeExtArray)) break;
         double slope_ext_price = SlopeExtArray[slope_ext_offset];
         
         double candle_high = iHigh(_Symbol, _Period, signal_idx);
         double candle_low = iLow(_Symbol, _Period, signal_idx);
         double candle_close = iClose(_Symbol, _Period, signal_idx);
         
         if(signal_is_sell) {
            // SELL: Check if HIGH breaks above slope extension → stop
            double break_price = extension_break_close ? candle_close : candle_high;
            if(break_price > slope_ext_price) break;
            
            // SELL signal when close goes BELOW golden line
            if(candle_close >= trend_price) continue;
            
            draw_arrow("sell", signal_idx, candle_high);
         } else {
            // BUY: Check if LOW breaks below slope extension → stop
            double break_price = extension_break_close ? candle_close : candle_low;
            if(break_price < slope_ext_price) break;
            
            // BUY signal when close goes ABOVE golden line
            if(candle_close <= trend_price) continue;
            
            draw_arrow("buy", signal_idx, candle_low);
         }
         break;
      }
      
      // Draw golden line
      if(draw_golden_line) {
         Print("GL_DOWNTREND: SUCCESS! Drawing golden line mn_start_idx=", mn_start_idx, 
               " mn_start_price=", DoubleToString(mn_start_price, 5), " last_idx=", last_idx);
         int ext_bars = MathMin(mn_extension_bars, last_idx);
         int mn_end_offset = mn_start_idx - last_idx + ext_bars - 1;
         Print("GL_DOWNTREND: ext_bars=", ext_bars, " mn_end_offset=", mn_end_offset, " ArraySize=", ArraySize(MNArray));
         if(mn_end_offset > 0 && mn_end_offset < ArraySize(MNArray))
            draw_golden_line_obj("golden", g_wave.x_idx, mn_start_idx, mn_start_price, 
                                 last_idx - ext_bars + 1, MNArray[mn_end_offset], golden_line_color);
         else
            Print("GL_DOWNTREND: NOT DRAWING - mn_end_offset out of bounds");
      }
      
      // Draw FG separator if enabled
      if(draw_fg_line && ArraySize(FGArray) > 0)
         draw_golden_line_obj("fg", g_wave.x_idx, fg_start_idx, fg_start_price, 
                              last_idx, FGArray[bars_fg], fg_line_color);
      
      return;
   }
   
   // If we get here, we exhausted all slope iterations without finding valid M/N
   Print("GL_DOWNTREND: FAILED - no valid M/N points found after matrix computation");
   
   // FALLBACK: Draw a simple golden line from SP to last point for debugging
   if(draw_golden_line) {
      Print("GL_DOWNTREND: Drawing FALLBACK golden line from sp_idx=", sp_idx, " to last_idx=", last_idx);
      draw_golden_line_obj("golden_fallback", g_wave.x_idx, sp_idx, sp_price, 
                           last_idx - mn_extension_bars, last_price, golden_line_color);
   }
}

//+------------------------------------------------------------------+

