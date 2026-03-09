//+------------------------------------------------------------------+
//|                                                       phase1.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include  <Trade\Trade.mqh>
CTrade Trade;


#include  <patterns_inputs.mqh>
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
  };

wave_struct my_wave_struct = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
//---

int _handled_signals[];

MqlRates mrate[];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   fill_sets();
   ArrayFree(_handled_signals);

   for(int i = 0; i < ArraySize(global_sets_array); i++)
     {
      set_global_set(global_sets_array[i]);
      if(!active_set)
         continue;
      start_pattern(Bars(_Symbol, _Period) - 1);
     }


   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, Prefix);
   ChartRedraw();
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

   first_checks();

   if(isNewBar())
     {
      for(int i = 0; i < ArraySize(global_sets_array); i++)
        {
         set_global_set(global_sets_array[i]);
         if(!active_set)
            continue;
         start_pattern(b_max + 1);
        }
     }


  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void start_pattern(int idx)
  {
   update_rates();

   if(pattern_direction == Bullish)
      phase_one(idx);

   if(pattern_direction == Bearish)
      phase_one_bearish(idx);

   if(pattern_direction == Both)
     {
      phase_one(idx);
      phase_one_bearish(idx);
     }

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void phase_one_bearish(int _idx)
  {

   draw_progress("Updating ...", clrGray);

   int x_bars = _idx; //Oldest bar index

   for(int x_idx = x_bars ; x_idx > 0; x_idx--)
     {

      if(testing_mode)
        {
         if(iTime(_Symbol, PERIOD_CURRENT, x_idx) > StringToTime(end_test_time))
            continue;

         if(iTime(_Symbol, PERIOD_CURRENT, x_idx) < StringToTime(start_test_time))
            continue;
        }

      if(bars_limit != 0 && x_idx > bars_limit)
         continue;

      // OUTER Loop
      // Calculating XB Line
      double x_price = iHigh(_Symbol, _Period, x_idx);
      if(x_price == 0)
         continue;

      double dynamic_max_width_percentage;
      double dynamic_min_width_percentage;

      int b_start_idx = x_idx - 1 - b_min;

      // adding x to struct
      my_wave_struct.x_idx = x_idx;
      my_wave_struct.x_price = x_price;

      for(int b_idx = b_start_idx; b_idx > x_idx - b_max; b_idx--)
        {
         // INNER LOOP
         double b_price = iHigh(_Symbol, _Period, b_idx);
         int bars_x_b = x_idx - b_idx; // X_B Step
         double StepXB;
         double XBArray[];
         bool _continue_b = false;

         StepXB = (b_price - x_price) / bars_x_b;
         for(int j = 1; j <= bars_x_b; j++)
           {
            append_double(XBArray, (x_price + j * StepXB));
           }

         // Calculating PX Line
         int bars_p_x = int(px_lenght_percentage * 0.01 * bars_x_b); // PX Bars count

         // If there is not enough bars prior to x we continue
         if(x_bars - x_idx < bars_p_x)
            break;

         int p_idx = x_idx + bars_p_x;
         double p_price = x_price - (bars_p_x * StepXB);

         // PX array
         double px_array[];
         for(int px_array_idx = 0; px_array_idx < bars_x_b; px_array_idx++)
           {

            append_double(px_array, p_price + px_array_idx * StepXB);
           }

         // Looping though PX Array to find lower point in price than px value
         for(int px_idx = 0 ; px_idx < bars_p_x; px_idx++)
           {
            int real_p_idx = x_idx + 1 + px_idx;
            double p_bar_low = iHigh(_Symbol, _Period, real_p_idx);
            double p_array_value = px_array[bars_p_x - 1 - px_idx];

            if(p_bar_low > p_array_value)
              {
               _continue_b = true;
               break;
              }
           }

         if(_continue_b)
            continue;

         // Looping though XB Array to find lower point in price than XB value
         for(int xb_idx = 0 ; xb_idx < bars_x_b; xb_idx++)
           {
            int real_b_idx = x_idx - xb_idx - 1 ;
            double b_bar_low = iHigh(_Symbol, _Period, real_b_idx);
            double b_array_value = XBArray[xb_idx];

            if(b_bar_low > b_array_value)
              {
               _continue_b = true;
               break;
              }
           }

         if(_continue_b)
            continue;

         // adding B to struct
         my_wave_struct.b_idx = b_idx;
         my_wave_struct.b_price = b_price;

         // adding P to struct
         my_wave_struct.p_idx = p_idx;
         my_wave_struct.p_price = p_price;

         // ===================
         // Calculation A Point
         // ===================

         // Making the array of A and B difference
         double ab_diff_array[];
         for(int ab_idx = 0; ab_idx < bars_x_b; ab_idx++)
           {
            double ab_diff =  XBArray[ab_idx] - iLow(_Symbol, _Period, x_idx - ab_idx);
            append_double(ab_diff_array,  ab_diff);
           }

         int a_idx =  x_idx - ArrayMaximum(ab_diff_array);
         double a_price = iLow(_Symbol, _Period, a_idx);

         // Filtering b with Min and Max percentage
         double max_val = x_price - (x_price - a_price) * x_to_a_b_max * 0.01;
         double min_val = x_price - (x_price - a_price) * x_to_a_b_min * 0.01;

         if(b_price < max_val || b_price > min_val)
            continue;

         // Checking for a new high between a and b idx if b > x
         int _tmp_a_idx = a_idx;
         if(b_price < x_price)
           {
            for(int high_a = a_idx; high_a > b_idx; high_a--)
              {
               double high_a_price = iLow(_Symbol, _Period, high_a);
               if(high_a_price < a_price)
                 {
                  _tmp_a_idx = high_a;
                  a_price = high_a_price;
                 }
              }
           }

         // Checking for a new high between x and a idx if b < x
         else
           {
            for(int high_a = x_idx ; high_a >= a_idx; high_a--)
              {
               double high_a_price = iLow(_Symbol, _Period, high_a);
               if(high_a_price < a_price)
                 {
                  _tmp_a_idx = high_a;
                  a_price = high_a_price;
                 }
              }
           }
         a_idx = _tmp_a_idx;

         // calculating Dynamic width size
         int dynamic_candles_count = b_start_idx - b_idx;
         double increasing_width_value = ((int)(dynamic_candles_count / every_increasing_of_value) + 1) * width_increasing_percentage_x_to_b;
         dynamic_max_width_percentage = max_width_percentage + increasing_width_value;
         dynamic_min_width_percentage = min_width_percentage + increasing_width_value;

         // calculating vertical range for A
         double z = XBArray[x_idx - a_idx];
         double a_upper_boundary = z - (z * dynamic_max_width_percentage * 0.01);
         double a_lower_boundary = z - (z * dynamic_min_width_percentage * 0.01) ;
         if(a_price < a_upper_boundary || a_price > a_lower_boundary)
            continue;


         // adding A to struct
         my_wave_struct.a_idx = a_idx;
         my_wave_struct.a_price = a_price;

         if(pattern_type == X_A_B)
           {
            // checking divergence
            if(!divergence_filter(x_idx, a_idx, b_idx, 1))
               continue;

            // checking tickchart speed
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

         // ===================
         // Calculating C Point
         // ===================

         int c_min_idx = a_idx - (int)(bars_x_b * min_a_to_c_btw_x_b * 0.01);
         int c_max_idx = a_idx - (int)(bars_x_b * max_a_to_c_btw_x_b * 0.01);
         if(c_min_idx >= b_idx)
            c_min_idx = b_idx - 1;

         // Continuation of xb line
         double BCArray[];
         for(int bc_idx = 1; bc_idx <= b_idx - c_max_idx; bc_idx++)
           {
            append_double(BCArray, b_price +  bc_idx * StepXB);
           }

         //Check if C inside the percentage levels from AB leg
         double c_upper_boundary = b_price - (b_price - a_price) * max_width_c_ab * 0.01;
         double c_lower_boundary = b_price - (b_price - a_price) * min_width_c_ab * 0.01;

         //Check if C inside the percentage levels from XA leg
         double c_upper_boundary_xa = x_price - (x_price - a_price) * max_width_c_xa * 0.01;
         double c_lower_boundary_xa = x_price - (x_price - a_price) * min_width_c_xa * 0.01;

         // Loop for C indside B
         for(int c_idx = c_min_idx; c_idx > c_max_idx; c_idx--)
           {
            bool _continue_c = false;
            double current_c_low = iHigh(_Symbol, _Period, c_idx);
            double c_price = iLow(_Symbol, _Period, c_idx);
            int bars_a_c = a_idx - c_idx;

            // Checking if c price is higher than  ac array
            for(int i = 0; i < b_idx - c_idx; i++)
              {
               double tmp_low = iHigh(_Symbol, _Period, b_idx - i - 1);
               double tmp_bc_val = BCArray[i];
               if(tmp_low > tmp_bc_val)
                 {
                  _continue_c = true;
                  break;
                 }
              }

            if(_continue_c)
               continue;

            // Check if C inside the percentage levels from AB leg
            if(c_price < c_upper_boundary || c_price > c_lower_boundary)
              {
               continue;
              }

            // Check if C inside the percentage levels from AB leg
            if(c_price < c_upper_boundary_xa || c_price > c_lower_boundary_xa)
              {
               continue;
              }

            // making the array of AC
            double StepAC = (c_price - a_price) / bars_a_c;
            double ACArray[];
            double New_ACArray[]; // ACArray with dynamic size added
            for(int j = 1; j <= bars_a_c; j++)
              {
               int idx = (int)((b_start_idx - b_idx) / every_increasing_of_value);
               double real_ac_val = (a_price + j * StepAC);
               append_double(ACArray, real_ac_val);
               append_double(New_ACArray, real_ac_val - real_ac_val * idx * width_increasing_percentage_a_e * 0.01);
              }

            // Checking if c price is higher than new ac array
            for(int i = 0; i < bars_a_c; i++)
              {
               double new_ac_array_val = New_ACArray[i];
               double temp_c_val = iLow(_Symbol, _Period, a_idx - i - 1);
               if(temp_c_val < new_ac_array_val)
                 {
                  _continue_c = true;
                  break;
                 }
              }

            if(_continue_c)
               continue;

            // adding C to struct
            my_wave_struct.c_idx = c_idx;
            my_wave_struct.c_price = c_price;

            if(pattern_type == X_A_B_C)
              {
               // checking divergence
               if(!divergence_filter(a_idx, b_idx, c_idx, -1))
                  continue;

               // checking tickchart speed
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

            // ===================
            // Calculating D Point
            // ===================

            int d_min_idx = b_idx - (int)(bars_x_b * min_b_to_d_btw_x_b * 0.01);
            int d_max_idx = b_idx - (int)(bars_x_b * max_b_to_d_btw_x_b * 0.01);
            if(d_min_idx >= c_idx)
               d_min_idx = c_idx - 1;

            // Continuation of ac line
            double ACArrayExt[];
            for(int i = 1; i <= b_idx - d_max_idx; i++)
              {
               append_double(ACArrayExt, c_price +  i * StepAC);
              }

            //Check if D inside the percentage levels from BC leg
            double d_upper_boundary_bc = b_price - (b_price - c_price) * max_width_d_bc * 0.01;
            double d_lower_boundary_bc = b_price - (b_price - c_price) * min_width_d_bc * 0.01;

            //Check if D inside the percentage levels from XA leg
            double d_upper_boundary_xa = x_price - (x_price - a_price) * max_width_d_xa * 0.01;
            double d_lower_boundary_xa = x_price - (x_price - a_price) * min_width_d_xa * 0.01;

            // Loop for D indside C
            for(int d_idx = d_min_idx; d_idx > d_max_idx; d_idx--)
              {

               bool _continue_d = false;
               double current_d_low = iHigh(_Symbol, _Period, d_idx);
               double d_price = iHigh(_Symbol, _Period, d_idx);
               int bars_b_d = b_idx - d_idx;

               // Checking if d price is higher than new ac array
               for(int i = 0; i < c_idx - d_idx; i++)
                 {
                  double tmp_high = iLow(_Symbol, _Period, c_idx - i - 1);
                  double tmp_ac_val = ACArrayExt[i];
                  if(tmp_high < tmp_ac_val)
                    {
                     _continue_d = true;
                     break;
                    }
                 }

               if(_continue_d)
                  continue;

               // Check if D inside the percentage levels from BC leg
               if(d_price < d_upper_boundary_bc || d_price > d_lower_boundary_bc)
                 {
                  continue;
                 }

               // Check if D inside the percentage levels from XA leg
               if(d_price < d_upper_boundary_xa || d_price > d_lower_boundary_xa)
                 {
                  continue;
                 }

               // making the array of BD
               double StepBD = (d_price - b_price) / bars_b_d;
               double BDArray[];
               double New_BDArray[]; // ACArray with dynamic size added
               for(int j = 1; j <= bars_b_d; j++)
                 {
                  int idx = (int)((b_start_idx - b_idx) / every_increasing_of_value);
                  double real_bd_val = (b_price + j * StepBD);
                  append_double(BDArray, real_bd_val);
                  append_double(New_BDArray, real_bd_val + real_bd_val * idx * width_increasing_percentage_a_e * 0.01);
                 }

               // Checking if D price is lower than new BD array
               for(int i = 0; i < bars_b_d; i++)
                 {
                  double new_bd_array_val = New_BDArray[i];
                  double temp_d_val = iHigh(_Symbol, _Period, b_idx - i - 1);
                  if(temp_d_val > new_bd_array_val)
                    {
                     _continue_d = true;
                     break;
                    }
                 }

               if(_continue_d)
                  continue;

               // adding D to struct
               my_wave_struct.d_idx = d_idx;
               my_wave_struct.d_price = d_price;

               if(pattern_type == X_A_B_C_D)
                 {
                  // checking divergence
                  if(!divergence_filter(b_idx, c_idx, d_idx, 1))
                     continue;

                  // checking tickchart speed
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

               // ===================
               // Calculating E Point
               // ===================

               int e_min_idx = c_idx - (int)(bars_x_b * min_c_to_e_btw_x_b * 0.01);
               int e_max_idx = c_idx - (int)(bars_x_b * max_c_to_e_btw_x_b * 0.01);
               if(e_min_idx >= d_idx)
                  e_min_idx = d_idx - 1;

               // Continuation of BD line
               double BDArrayExt[];
               for(int i = 1; i <= d_idx - e_max_idx; i++)
                 {
                  append_double(BDArrayExt, d_price +  i * StepBD);
                 }

               //Check if E inside the percentage levels from CD leg
               double e_upper_boundary_cd = d_price - (d_price - c_price) * max_width_e_cd * 0.01;
               double e_lower_boundary_cd = d_price - (d_price - c_price) * min_width_e_cd * 0.01;

               //Check if E inside the percentage levels from XA leg
               double e_upper_boundary_xa = x_price - (x_price - a_price) * max_width_e_xa * 0.01;
               double e_lower_boundary_xa = x_price - (x_price - a_price) * min_width_e_xa * 0.01;

               // Loop for E indside D
               for(int e_idx = e_min_idx; e_idx > e_max_idx; e_idx--)
                 {

                  bool _continue_e = false;
                  double current_e_low = iHigh(_Symbol, _Period, e_idx);
                  double e_price = iLow(_Symbol, _Period, e_idx);
                  int bars_c_e = c_idx - e_idx;

                  // Checking if e price is lower than new array
                  for(int i = 0; i < d_idx - e_idx; i++)
                    {
                     double tmp_low = iHigh(_Symbol, _Period, d_idx - i - 1);
                     double tmp_bd_val = BDArrayExt[i];
                     if(tmp_low > tmp_bd_val)
                       {
                        _continue_e = true;
                        break;
                       }
                    }

                  if(_continue_e)
                     continue;

                  // Check if E inside the percentage levels from CD leg
                  if(e_price < e_upper_boundary_cd || e_price > e_lower_boundary_cd)
                    {
                     continue;
                    }

                  // Check if E inside the percentage levels from XA leg
                  if(e_price < e_upper_boundary_xa || e_price > e_lower_boundary_xa)
                    {
                     continue;
                    }

                  // making the array of CE
                  double StepCE = (e_price - c_price) / bars_c_e;
                  double CEArray[];
                  double New_CEArray[]; // CEArray with dynamic size added
                  for(int j2 = 1; j2 <= bars_c_e; j2++)
                    {
                     int idx = (int)((b_start_idx - b_idx) / every_increasing_of_value);
                     double real_ce_val = (c_price + j2 * StepCE);
                     append_double(CEArray, real_ce_val);
                     append_double(New_CEArray, real_ce_val - real_ce_val * idx * width_increasing_percentage_a_e * 0.01);
                    }

                  // Checking if E price is higher than new CE array
                  for(int i = 0; i < bars_c_e; i++)
                    {
                     double new_ce_array_val = New_CEArray[i];
                     double temp_e_val = iLow(_Symbol, _Period, c_idx - i - 1);
                     if(temp_e_val < new_ce_array_val)
                       {
                        _continue_e = true;
                        break;
                       }
                    }

                  if(_continue_e)
                     continue;

                  // adding E to struct
                  my_wave_struct.e_idx = e_idx;
                  my_wave_struct.e_price = e_price;

                  if(pattern_type == X_A_B_C_D_E)
                    {
                     // checking divergence
                     if(!divergence_filter(c_idx, d_idx, e_idx, -1))
                        continue;

                     // checking tickchart speed
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
//|                                                                  |
//+------------------------------------------------------------------+
void phase_two_bearish(pattern_type_enum _type, wave_struct& _wave_struct)
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


   if(_type == X_A_B)
     {

      // making XB array
      int bars_x_b = x_idx - b_idx;
      double StepXB = (b_price - x_price) / bars_x_b ;
      double XBArray[];
      for(int i = 0; i < bars_x_b; i++)
        {
         append_double(XBArray, x_price + i * StepXB);
        }

      // Naming Z
      double z_price = XBArray[x_idx - a_idx];
      int z_idx = a_idx;

      //set starting point
      double sp_price = a_price;
      int sp_idx = a_idx;

      int idxs_above_fg[];
      int idxs_below_fg[];
      double FGArray[];
      double f_price;
      int f_idx;
      int bars_f_g;
      for(int q = 0; q <= (int)((100 - f_percentage) / fg_increasing_percentage) + 1; q++)
        {
         ArrayFree(idxs_above_fg);
         ArrayFree(idxs_below_fg);
         ArrayFree(FGArray);

         double p_to_check = f_percentage + q * fg_increasing_percentage;
         if(p_to_check > 100)
            p_to_check = 100;

         // F point price. the point that parallel line to AC starts from
         f_price = z_price - (z_price - a_price) * p_to_check * 0.01;
         f_idx =  z_idx;

         // Making FG array. the line paralel to AE/CE
         double StepFG = StepXB;
         bars_f_g = f_idx - b_idx;
         for(int i = 0; i <= bars_f_g; i++)
           {
            append_double(FGArray, f_price + i * StepFG);
           }

         double _last_bar_limit  = iLow(_Symbol, _Period, b_idx);
         if(_last_bar_limit < FGArray[ArraySize(FGArray) - 1])
            continue;

         // findidng the indices above and below fg line
         for(int i = 0; i <= sp_idx - b_idx; i++)
           {
            double _tmp_p = iLow(_Symbol, _Period, sp_idx - i);
            double _tmp_fg = FGArray[i];
            if(_tmp_p > _tmp_fg)
               append_int(idxs_above_fg, i);
            else
               append_int(idxs_below_fg, i);
           }

         if(ArraySize(idxs_above_fg) == 0 || ArraySize(idxs_below_fg) == 0)
            continue;

         //---
         int bars_sp_b = sp_idx - b_idx;
         for(int j = (int)(first_line_percentage / first_line_decrease_percentage)  ; j >= 0 ; j--)
           {
            // Making firs line array
            double FirstLineArray[];
            double _slope = (sp_price * (first_line_percentage - j * first_line_decrease_percentage) * 0.01) / (sp_idx - b_idx);
            for(int i = 0; i <= sp_idx - b_idx; i++)
              {
               double _tmp_  = sp_price +  _slope * i ;
               append_double(FirstLineArray, _tmp_);
              }

            // different between highs and slope line array for above price
            double above_diff_array[];
            int above_diff_idx_array[];
            for(int i = 0; i < ArraySize(idxs_above_fg); i++)
              {
               int _idx = idxs_above_fg[i];
               append_double(above_diff_array, FirstLineArray[_idx] - iLow(_Symbol, _Period, sp_idx - _idx));
               append_int(above_diff_idx_array, _idx);
              }

            // different between highs and slope line array for below price
            double below_diff_array[];
            int below_diff_idx_array[];
            for(int i = 0; i < ArraySize(idxs_below_fg); i++)
              {
               int _idx = idxs_below_fg[i];
               append_double(below_diff_array, FirstLineArray[_idx] - iLow(_Symbol, _Period, sp_idx - _idx));
               append_int(below_diff_idx_array, _idx);
              }

            // Finding max in above diff and max in below diff
            double max_above_diff = above_diff_array[ ArrayMaximum(above_diff_array) ] ;
            double max_below_diff = below_diff_array[ ArrayMaximum(below_diff_array) ] ;

            if(max_below_diff < 0 || max_above_diff < 0)
               continue;

            // M N differnce percentage
            double max_diff_percentage;
            max_diff_percentage = MathAbs(max_above_diff - max_below_diff) / MathAbs(a_price - b_price);

            // MN found making the extension
            int max_above_idx = sp_idx - above_diff_idx_array[ ArrayMaximum(above_diff_array) ] ;
            int max_below_idx = sp_idx - below_diff_idx_array[ ArrayMaximum(below_diff_array) ] ;

            if(MathAbs(max_above_idx - max_below_idx) < mn_length_percent * 0.01 * (a_idx - b_idx))
               continue;

            double max_above_price = iLow(_Symbol, _Period, max_above_idx);
            double max_below_price = iLow(_Symbol, _Period, max_below_idx);
            if(max_diff_percentage > maxBelow_maxAbove_diff_percentage * 0.01 && max_diff_percentage != 1.0)
               continue;

            if(max_below_price > max_above_price)
               continue;

            if(max_below_idx <= max_above_idx)
               continue;

            double StepMN = (max_above_price - max_below_price) / (max_below_idx - max_above_idx);
            double MNArray[];
            max_below_price = max_below_price - (max_above_price - max_below_price) * mn_buffer_percent * 0.01 ;
            for(int i = 0 ; i < max_below_idx - b_idx + mn_extension_bars; i++)
              {
               append_double(MNArray, max_below_price + i * StepMN);
              }

            // Trend line found . searching for breakout from that line
            double phase2Array[];
            int phase2Idx;
            ArrayCopy(phase2Array, MNArray);
            phase2Idx = max_below_idx;

            // making AE Extension array
            double XBExtArray[];
            ArrayCopy(XBExtArray, XBArray);
            for(int i = 0; i <= mn_extension_bars; i++)
              {
               append_double(XBExtArray, b_price + i * StepXB);
              }

            // looping for after D
            for(int i = 1; i < mn_extension_bars; i++)
              {
               int real_idx = b_idx - i;

               if(real_idx < 1)
                  break;

               double trend_price = MNArray[phase2Idx - b_idx + i];
               double ext_price = XBExtArray[x_idx - b_idx + i];
               double _high = mrate[real_idx].high;
               double _low = mrate[real_idx].low;
               double _open = mrate[real_idx].open;
               double _close = mrate[real_idx].close;

               double _break_price;
               if(extension_break_close)
                  _break_price = _close;
               else
                  _break_price = _high;

               if(_break_price > ext_price)
                  break;

               if(_close >= trend_price)
                  continue;

               if(!filter_candle_pattern(-1, real_idx))
                  continue;

               //found. drawing arrow
               draw_arrow("sell", real_idx, _high);
               handle_signal(real_idx, -1, _type, _wave_struct);
               break;
              }

            if(draw_lines)
              {
               if(draw_mn)
                  draw_line("mn ext", 0, max_below_idx, max_below_price, b_idx - mn_extension_bars + 1, MNArray[mn_extension_bars + max_below_idx - b_idx - 1], mn_color);
               if(draw_fg)
                  draw_line("fg", 0, f_idx, FGArray[0], b_idx, FGArray[ ArraySize(FGArray) - 1 ], fg_color);
               if(draw_slope)
                  draw_line("first", 0, sp_idx, FirstLineArray[0], b_idx, FirstLineArray[ ArraySize(FirstLineArray) - 1 ], slope_color);
              }
            return;
           }
        }
     }


   if(_type == X_A_B_C)
     {
      // making AC array
      int bars_a_c = a_idx - c_idx;
      double StepAC = (c_price - a_price) / bars_a_c ;
      double ACArray[];
      for(int i = 0; i < bars_a_c; i++)
        {
         append_double(ACArray, a_price + i * StepAC);
        }

      // set starting point
      double sp_price = b_price;
      int sp_idx = b_idx;

      // Naming Z Point:
      double z_price = ACArray[a_idx - b_idx];
      int z_idx = b_idx;

      int idxs_above_fg[];
      int idxs_below_fg[];
      double FGArray[];
      double f_price;
      int f_idx;
      int bars_f_g;
      for(int q = 0; q <= (int)((100 - f_percentage) / fg_increasing_percentage) + 1; q++)
        {
         ArrayFree(idxs_above_fg);
         ArrayFree(idxs_below_fg);
         ArrayFree(FGArray);

         double p_to_check = f_percentage + q * fg_increasing_percentage;
         if(p_to_check > 100)
            p_to_check = 100;

         // F point price. the point that parallel line to XB starts from
         f_price  = z_price + (b_price - z_price) * p_to_check * 0.01;
         f_idx = z_idx;

         // Making FG array. the line paralel to XA/BD
         double StepFG = StepAC ;
         bars_f_g = f_idx - c_idx;
         for(int i = 0; i <= bars_f_g; i++)
           {
            append_double(FGArray, f_price + i * StepFG);
           }

         double _last_bar_limit  = iHigh(_Symbol, _Period, c_idx);
         if(_last_bar_limit >= FGArray[ArraySize(FGArray) - 1])
            continue;

         // findidng the indices above and below fg line
         for(int i = 0; i <= sp_idx - c_idx; i++)
           {
            double _tmp_p = iHigh(_Symbol, _Period, sp_idx - i);
            double _tmp_fg = FGArray[i];
            if(_tmp_p >= _tmp_fg)
               append_int(idxs_above_fg, i);
            else
               append_int(idxs_below_fg, i);
           }

         if(ArraySize(idxs_above_fg) == 0 || ArraySize(idxs_below_fg) == 0)
            continue;

         int bars_sp_c = sp_idx - c_idx;
         for(int j = (int)(first_line_percentage / first_line_decrease_percentage)  ; j >= 0 ; j--)
           {
            // Making first line array
            double FirstLineArray[];
            double _slope = (sp_price * (first_line_percentage - j * first_line_decrease_percentage) * 0.01) / (sp_idx - c_idx);
            for(int i = 0; i <= sp_idx - c_idx; i++)
              {
               double _tmp_  = sp_price -  _slope * i ;
               append_double(FirstLineArray, _tmp_);
              }

            // different between highs and slope line array for above price
            double above_diff_array[];
            int above_diff_idx_array[];
            for(int i = 0; i < ArraySize(idxs_above_fg); i++)
              {
               int _idx = idxs_above_fg[i];
               append_double(above_diff_array, iHigh(_Symbol, _Period, sp_idx - _idx) - FirstLineArray[_idx]);
               append_int(above_diff_idx_array, _idx);
              }

            // different between highs and slope line array for below price
            double below_diff_array[];
            int below_diff_idx_array[];
            for(int i = 0; i < ArraySize(idxs_below_fg); i++)
              {
               int _idx = idxs_below_fg[i];
               append_double(below_diff_array, iHigh(_Symbol, _Period, sp_idx - _idx) - FirstLineArray[_idx]);
               append_int(below_diff_idx_array, _idx);
              }

            // Finding max in above diff and max in below diff
            double max_above_diff = above_diff_array[ ArrayMaximum(above_diff_array) ] ;
            double max_below_diff = below_diff_array[ ArrayMaximum(below_diff_array) ] ;

            if(max_below_diff < 0 || max_above_diff < 0)
               continue;

            // M N differnce percentage
            double max_diff_percentage;
            max_diff_percentage = MathAbs(max_above_diff - max_below_diff) / MathAbs(b_price - c_price);

            if(max_diff_percentage > maxBelow_maxAbove_diff_percentage * 0.01 && max_diff_percentage != 1.0)
               continue;

            // MN found making the extension
            int max_above_idx = sp_idx - above_diff_idx_array[ ArrayMaximum(above_diff_array) ] ;
            int max_below_idx = sp_idx - below_diff_idx_array[ ArrayMaximum(below_diff_array) ] ;

            double max_above_price = iHigh(_Symbol, _Period, max_above_idx);
            double max_below_price = iHigh(_Symbol, _Period, max_below_idx);
            if(max_diff_percentage > maxBelow_maxAbove_diff_percentage * 0.01 && max_diff_percentage != 1.0)
               continue;

            if(max_below_price > max_above_price)
               continue;

            if(max_below_idx >= max_above_idx)
               continue;

            double StepMN = (max_below_price - max_above_price) / (max_above_idx - max_below_idx);
            double MNArray[];
            max_above_price = max_above_price + (max_above_price - max_below_price) * mn_buffer_percent * 0.01 ;
            for(int i = 0 ; i < max_above_idx - c_idx + mn_extension_bars; i++)
              {
               append_double(MNArray, max_above_price + i * StepMN);
              }

            // Trend line found . searching for breakout from that line
            double phase2Array[];
            int phase2Idx;
            ArrayCopy(phase2Array, MNArray);
            phase2Idx = max_above_idx;

            // making AC Extension array
            double ACExtArray[];
            ArrayCopy(ACExtArray, ACArray);
            for(int i = 0; i <= mn_extension_bars; i++)
              {
               append_double(ACExtArray, c_price + i * StepAC);
              }

            // looping for after D
            for(int i = 1; i < mn_extension_bars; i++)
              {
               int real_idx = c_idx - i;

               if(real_idx < 1)
                  break;

               double trend_price = MNArray[phase2Idx - c_idx + i];
               double ext_price = ACExtArray[a_idx - c_idx + i];
               double _high = mrate[real_idx].high;
               double _low = mrate[real_idx].low;
               double _open = mrate[real_idx].open;
               double _close = mrate[real_idx].close;

               double _break_price;
               if(extension_break_close)
                  _break_price = _close;
               else
                  _break_price = _low;

               if(_break_price < ext_price)
                  break;

               if(_close <= trend_price)
                  continue;

               if(!filter_candle_pattern(1, real_idx))
                  continue;

               //found. drawing arrow
               draw_arrow("buy", real_idx, _low);
               handle_signal(real_idx, 1, _type, _wave_struct);
               break;
              }

            if(draw_lines)
              {
               if(draw_mn)
                  draw_line("mn ext", 0, max_above_idx, max_above_price, c_idx - mn_extension_bars + 1, MNArray[mn_extension_bars + max_above_idx - c_idx - 1], mn_color);
               if(draw_fg)
                  draw_line("fg", 0, f_idx, FGArray[0], c_idx, FGArray[ ArraySize(FGArray) - 1 ], fg_color);
               if(draw_slope)
                  draw_line("first", 0, sp_idx, FirstLineArray[0], c_idx, FirstLineArray[ ArraySize(FirstLineArray) - 1 ], slope_color);

              }
            return;

           }
        }

     }


   if(_type == X_A_B_C_D)
     {
      // making XD array
      int bars_x_d = x_idx - d_idx;
      double StepXD = (d_price - x_price) / bars_x_d ;
      double XDArray[];
      for(int i = 0; i < bars_x_d; i++)
        {
         append_double(XDArray, x_price + i * StepXD);
        }

      // making BD array
      int bars_b_d = b_idx - d_idx;
      double StepBD = (d_price - b_price) / bars_b_d ;
      double BDArray[];
      for(int i = 0; i < bars_b_d; i++)
        {
         append_double(BDArray, b_price + i * StepBD);
        }

      // checking if B is lower than XD
      bool b_is_lower = false;
      if(b_price < XDArray[x_idx - b_idx])
        {
         b_is_lower = true;
        }

      // Naming Z and Y Point:
      double z_price;
      int z_idx;
      double sp_price;
      int sp_idx;
      sp_price = c_price;
      sp_idx = c_idx;

      if(b_is_lower)
        {
         z_price = XDArray[x_idx - c_idx - 1];
         z_idx = c_idx;
        }
      else
        {
         z_price = BDArray[b_idx - c_idx - 1];
         z_idx = c_idx;
        }

      int idxs_above_fg[];
      int idxs_below_fg[];
      double FGArray[];
      double f_price;
      int f_idx;
      int bars_f_g;
      for(int q = 0; q <= (int)((100 - f_percentage) / fg_increasing_percentage) + 1; q++)
        {
         ArrayFree(idxs_above_fg);
         ArrayFree(idxs_below_fg);
         ArrayFree(FGArray);

         double p_to_check = f_percentage + q * fg_increasing_percentage;
         if(p_to_check > 100)
           {
            p_to_check = 100;
           }

         // F point price. the point that parallel line to AC starts from
         f_price = z_price - (z_price - c_price) * p_to_check * 0.01;
         f_idx =  z_idx;

         // Making FG array. the line paralel to AE/CE
         double StepFG = b_is_lower ? StepXD : StepBD;
         bars_f_g = f_idx - d_idx;
         for(int i = 0; i <= bars_f_g; i++)
           {
            append_double(FGArray, f_price + i * StepFG);
           }


         double _last_bar_limit  = iLow(_Symbol, _Period, d_idx);
         if(_last_bar_limit <= FGArray[ArraySize(FGArray) - 1])
            continue;


         // findidng the indices above and below fg line
         for(int i = 0; i <= sp_idx - d_idx; i++)
           {
            double _tmp_p = iLow(_Symbol, _Period, sp_idx - i);
            double _tmp_fg = FGArray[i];
            if(_tmp_p > _tmp_fg)
               append_int(idxs_above_fg, i);
            else
               append_int(idxs_below_fg, i);
           }

         if(ArraySize(idxs_above_fg) == 0 || ArraySize(idxs_below_fg) == 0)
            continue;


         int bars_sp_d = sp_idx - d_idx;
         for(int j = (int)(first_line_percentage / first_line_decrease_percentage)  ; j >= 0 ; j--)
           {

            // Making firs line array
            double FirstLineArray[];
            double _slope = (sp_price * (first_line_percentage - j * first_line_decrease_percentage) * 0.01) / (sp_idx - d_idx);
            for(int i = 0; i <= sp_idx - d_idx; i++)
              {
               double _tmp_  = sp_price +  _slope * i ;
               append_double(FirstLineArray, _tmp_);
              }

            // different between highs and slope line array for above price
            double above_diff_array[];
            int above_diff_idx_array[];
            for(int i = 0; i < ArraySize(idxs_above_fg); i++)
              {
               int _idx = idxs_above_fg[i];
               append_double(above_diff_array, FirstLineArray[_idx] - iLow(_Symbol, _Period, sp_idx - _idx));
               append_int(above_diff_idx_array, _idx);
              }

            // different between highs and slope line array for below price
            double below_diff_array[];
            int below_diff_idx_array[];
            for(int i = 0; i < ArraySize(idxs_below_fg); i++)
              {
               int _idx = idxs_below_fg[i];
               append_double(below_diff_array, FirstLineArray[_idx] - iLow(_Symbol, _Period, sp_idx - _idx));
               append_int(below_diff_idx_array, _idx);
              }

            // Finding max in above diff and max in below diff
            double max_above_diff = above_diff_array[ ArrayMaximum(above_diff_array) ] ;
            double max_below_diff = below_diff_array[ ArrayMaximum(below_diff_array) ] ;

            if(max_below_diff < 0 || max_above_diff < 0)
               continue;

            // M N differnce percentage
            double max_diff_percentage;
            max_diff_percentage = MathAbs((max_above_diff - max_below_diff) / MathAbs(d_price - c_price));

            // MN found making the extension
            int max_above_idx = sp_idx - above_diff_idx_array[ ArrayMaximum(above_diff_array) ] ;
            int max_below_idx = sp_idx - below_diff_idx_array[ ArrayMaximum(below_diff_array) ] ;

            if(MathAbs(max_above_idx - max_below_idx) < mn_length_percent * 0.01 * (c_idx - d_idx))
               continue;

            double max_above_price = iLow(_Symbol, _Period, max_above_idx);
            double max_below_price = iLow(_Symbol, _Period, max_below_idx);

            if(max_diff_percentage > maxBelow_maxAbove_diff_percentage * 0.01 && max_diff_percentage != 1.0)
              {
               continue;
              }

            if(max_below_price > max_above_price)
               continue;

            if(max_below_idx <= max_above_idx)
               continue;

            double StepMN = (max_above_price - max_below_price) / (max_below_idx - max_above_idx);
            double MNArray[];
            max_below_price = max_below_price - (max_above_price - max_below_price) * mn_buffer_percent * 0.01 ;
            for(int i = 0 ; i < max_below_idx - d_idx + mn_extension_bars; i++)
              {
               append_double(MNArray, max_below_price + i * StepMN);
              }

            // Trend line found . searching for breakout from that line
            double phase2Array[];
            int phase2Idx;
            ArrayCopy(phase2Array, MNArray);
            phase2Idx = max_below_idx;

            // making AE Extension array
            double BDExtArray[];
            ArrayCopy(BDExtArray, BDArray);
            for(int i = 0; i <= mn_extension_bars; i++)
              {
               append_double(BDExtArray, d_price + i * StepBD);
              }

            // looping for after D
            for(int i = 1; i < mn_extension_bars; i++)
              {
               int real_idx = d_idx - i;

               if(real_idx < 1)
                  break;

               double trend_price = MNArray[phase2Idx - d_idx + i];
               double ext_price = BDExtArray[b_idx - d_idx + i];
               double _high = mrate[real_idx].high;
               double _low = mrate[real_idx].low;
               double _open = mrate[real_idx].open;
               double _close = mrate[real_idx].close;

               double _break_price;
               if(extension_break_close)
                  _break_price = _close;
               else
                  _break_price = _high;

               if(_break_price > ext_price)
                  break;

               if(_close >= trend_price)
                  continue;

               if(!filter_candle_pattern(-1, real_idx))
                  continue;

               //found. drawing arrow
               draw_arrow("sell", real_idx, _high);
               handle_signal(real_idx, -1, _type, _wave_struct);
               break;
              }

            if(draw_lines)
              {
               if(draw_mn)
                  draw_line("mn ext", 0, max_below_idx, max_below_price, d_idx - mn_extension_bars + 1, MNArray[mn_extension_bars + max_below_idx - d_idx - 1], mn_color);
               if(draw_fg)
                  draw_line("fg", 0, f_idx, FGArray[0], d_idx, FGArray[ ArraySize(FGArray) - 1 ], fg_color);
               if(draw_slope)
                  draw_line("first", 0, sp_idx, FirstLineArray[0], d_idx, FirstLineArray[ ArraySize(FirstLineArray) - 1 ], slope_color);

              }
            return;
           }
        }

     }


   if(_type == X_A_B_C_D_E)
     {
      // making AE array
      int bars_a_e = a_idx - e_idx;
      double StepAE = (e_price - a_price) / bars_a_e ;
      double AEArray[];
      for(int i = 0; i < bars_a_e; i++)
        {
         append_double(AEArray, a_price + i * StepAE);
        }

      // making CE array
      int bars_c_e = c_idx - e_idx;
      double StepCE = (e_price - c_price) / bars_c_e ;
      double CEArray[];
      for(int i = 0; i < bars_c_e; i++)
        {
         append_double(CEArray, c_price + i * StepCE);
        }

      // checking if C is higher than AE
      bool c_is_higher = false;
      if(c_price > AEArray[a_idx - c_idx])
        {
         c_is_higher = true;
        }

      // Naming Z and Y Point:
      double z_price;
      int z_idx;
      double sp_price;
      int sp_idx;

      double d_diff = d_price - AEArray[a_idx - d_idx];
      double b_diff = b_price - AEArray[a_idx - b_idx];
      double final_diff;

      if(c_is_higher)
        {
         if(d_diff > b_diff)
           {
            z_price = AEArray[a_idx - d_idx];
            z_idx = d_idx;
            sp_price = d_price;
            sp_idx = d_idx;
            final_diff = d_price - z_price;
           }
         else
           {
            z_price = AEArray[a_idx - b_idx];
            z_idx = b_idx;
            sp_price = b_price;
            sp_idx = b_idx;
            final_diff = b_diff;
           }

        }
      else
        {
         z_price = CEArray[c_idx - d_idx];
         z_idx = d_idx;
         sp_price = d_price;
         sp_idx = d_idx;
         final_diff = d_diff;
        }

      int idxs_above_fg[];
      int idxs_below_fg[];
      double FGArray[];
      double f_price;
      int f_idx;
      int bars_f_g;
      for(int q = 0; q <= (int)((100 - f_percentage) / fg_increasing_percentage) + 1; q++)
        {
         ArrayFree(idxs_above_fg);
         ArrayFree(idxs_below_fg);
         ArrayFree(FGArray);

         double p_to_check = f_percentage + q * fg_increasing_percentage;
         if(p_to_check > 100)
            p_to_check = 100;

         // F point price. the point that parallel line to XB starts from
         f_price  = z_price + final_diff * p_to_check * 0.01;
         f_idx = z_idx;

         // Making FG array. the line paralel to XA/BD
         double StepFG = c_is_higher ? StepAE : StepCE ;
         bars_f_g = f_idx - e_idx;
         for(int i = 0; i <= bars_f_g; i++)
           {
            append_double(FGArray, f_price + i * StepFG);
           }

         double _last_bar_limit  = iHigh(_Symbol, _Period, e_idx);
         if(_last_bar_limit >= FGArray[ArraySize(FGArray) - 1])
            continue;

         // findidng the indices above and below fg line
         for(int i = sp_idx - e_idx; i >= 0 ; i--)
           {
            double _tmp_p = iHigh(_Symbol, _Period, sp_idx - i);
            double _tmp_fg = FGArray[ i];
            if(_tmp_p >= _tmp_fg)
               append_int(idxs_above_fg, i);
            else
               append_int(idxs_below_fg, i);
           }

         if(ArraySize(idxs_above_fg) == 0 || ArraySize(idxs_below_fg) == 0)
            continue;

         int bars_sp_c = sp_idx - e_idx;
         for(int j = (int)(first_line_percentage / first_line_decrease_percentage)  ; j >= 0 ; j--)
           {
            // Making first line array
            double FirstLineArray[];
            double _slope = (sp_price * (first_line_percentage - j * first_line_decrease_percentage) * 0.01) / (sp_idx - e_idx);
            for(int i = 0; i <= sp_idx - e_idx; i++)
              {
               double _tmp_  = sp_price -  _slope * i ;
               append_double(FirstLineArray, _tmp_);
              }

            // different between highs and slope line array for above price
            double above_diff_array[];
            int above_diff_idx_array[];
            for(int i = 0; i < ArraySize(idxs_above_fg); i++)
              {
               int _idx = idxs_above_fg[i];
               append_double(above_diff_array, iHigh(_Symbol, _Period, sp_idx - _idx) - FirstLineArray[_idx]);
               append_int(above_diff_idx_array, _idx);
              }

            // different between highs and slope line array for below price
            double below_diff_array[];
            int below_diff_idx_array[];
            for(int i = 0; i < ArraySize(idxs_below_fg); i++)
              {
               int _idx = idxs_below_fg[i];
               append_double(below_diff_array, iHigh(_Symbol, _Period, sp_idx - _idx) - FirstLineArray[_idx]);
               append_int(below_diff_idx_array, _idx);
              }

            // Finding max in above diff and max in below diff
            double max_above_diff = above_diff_array[ ArrayMaximum(above_diff_array) ] ;
            double max_below_diff = below_diff_array[ ArrayMaximum(below_diff_array) ] ;

            if(max_below_diff < 0 || max_above_diff < 0)
               continue;

            // M N differnce percentage
            double max_diff_percentage;
            max_diff_percentage = MathAbs(max_above_diff - max_below_diff) /  MathAbs(e_price - d_price) ;

            // MN found making the extension
            int max_above_idx = sp_idx - above_diff_idx_array[ ArrayMaximum(above_diff_array) ] ;
            int max_below_idx = sp_idx - below_diff_idx_array[ ArrayMaximum(below_diff_array) ] ;

            if(MathAbs(max_above_idx - max_below_idx) < mn_length_percent * 0.01 * (d_idx - e_idx))
               continue;

            double max_above_price = iHigh(_Symbol, _Period, max_above_idx);
            double max_below_price = iHigh(_Symbol, _Period, max_below_idx);

            if(max_diff_percentage > maxBelow_maxAbove_diff_percentage * 0.01 && max_diff_percentage != 1.0)
               continue;

            if(max_below_price > max_above_price)
               continue;

            if(max_below_idx >= max_above_idx)
               continue;

            double StepMN = (max_below_price - max_above_price) / (max_above_idx - max_below_idx);
            double MNArray[];
            max_above_price = max_above_price + (max_above_price - max_below_price) * mn_buffer_percent * 0.01 ;
            for(int i = 0 ; i < max_above_idx - e_idx + mn_extension_bars; i++)
              {
               append_double(MNArray, max_above_price + i * StepMN);
              }

            // Trend line found . searching for breakout from that line
            double phase2Array[];
            int phase2Idx;
            ArrayCopy(phase2Array, MNArray);
            phase2Idx = max_above_idx;

            // making AC Extension array
            double CEExtArray[];
            ArrayCopy(CEExtArray, CEArray);
            for(int i = 0; i <= mn_extension_bars; i++)
              {
               append_double(CEExtArray, e_price + i * StepCE);
              }

            // looping for after D
            for(int i = 1; i < mn_extension_bars; i++)
              {
               int real_idx = e_idx - i;

               if(real_idx < 1)
                  break;

               double trend_price = MNArray[phase2Idx - e_idx + i];
               double ext_price = CEExtArray[c_idx - e_idx + i];
               double _high = mrate[real_idx].high;
               double _low = mrate[real_idx].low;
               double _open = mrate[real_idx].open;
               double _close = mrate[real_idx].close;

               double _break_price;
               if(extension_break_close)
                  _break_price = _close;
               else
                  _break_price = _low;

               if(_break_price < ext_price)
                  break;

               if(_close <= trend_price)
                  continue;

               if(!filter_candle_pattern(1, real_idx))
                  continue;

               //found. drawing arrow
               draw_arrow("buy", real_idx, _low);
               handle_signal(real_idx, 1, _type, _wave_struct);
               break;
              }

            if(draw_lines)
              {
               if(draw_mn)
                  draw_line("mn ext", 0, max_above_idx, max_above_price, e_idx - mn_extension_bars, MNArray[mn_extension_bars + max_above_idx - e_idx - 1], mn_color);
               if(draw_fg)
                  draw_line("fg", 0, f_idx, FGArray[0], e_idx, FGArray[ ArraySize(FGArray) - 1 ], fg_color);
               if(draw_slope)
                  draw_line("first", 0, sp_idx, FirstLineArray[0], e_idx, FirstLineArray[ ArraySize(FirstLineArray) - 1 ], slope_color);
              }
            return;
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void  phase_one(int _idx)
  {
   draw_progress("Updating ...", clrGray);

   int x_bars = _idx; //Oldest bar index

   for(int x_idx = x_bars ; x_idx > 0; x_idx--)
     {

      if(testing_mode)
        {
         if(iTime(_Symbol, PERIOD_CURRENT, x_idx) > StringToTime(end_test_time))
            continue;

         if(iTime(_Symbol, PERIOD_CURRENT, x_idx) < StringToTime(start_test_time))
            continue;
        }

      if(bars_limit != 0 && x_idx > bars_limit)
         continue;

      // OUTER Loop
      // Calculating XB Line
      double x_price = iLow(_Symbol, _Period, x_idx);
      if(x_price == 0)
         continue;

      double dynamic_max_width_percentage;
      double dynamic_min_width_percentage;

      int b_start_idx = x_idx - 1 - b_min;

      // adding x to struct
      my_wave_struct.x_idx = x_idx;
      my_wave_struct.x_price = x_price;

      for(int b_idx = b_start_idx; b_idx > x_idx - b_max; b_idx--)
        {
         // INNER LOOP
         double b_price = iLow(_Symbol, _Period, b_idx);
         int bars_x_b = x_idx - b_idx; // X_B Step
         double StepXB;
         double XBArray[];
         bool _continue_b = false;

         StepXB = (b_price - x_price) / bars_x_b;
         for(int j = 1; j <= bars_x_b; j++)
           {
            append_double(XBArray, (x_price + j * StepXB));
           }

         // Calculating PX Line
         int bars_p_x = int(px_lenght_percentage * 0.01 * bars_x_b); // PX Bars count

         // If there is not enough bars prior to x we continue
         if(x_bars - x_idx < bars_p_x)
            break;

         int p_idx = x_idx + bars_p_x;
         double p_price = x_price - (bars_p_x * StepXB);

         // PX array
         double px_array[];
         for(int px_array_idx = 0; px_array_idx < bars_x_b; px_array_idx++)
           {

            append_double(px_array, p_price + px_array_idx * StepXB);
           }

         // Looping though PX Array to find lower point in price than px value
         for(int px_idx = 0 ; px_idx < bars_p_x; px_idx++)
           {
            int real_p_idx = x_idx + 1 + px_idx;
            double p_bar_low = iLow(_Symbol, _Period, real_p_idx);
            double p_array_value = px_array[bars_p_x - 1 - px_idx];

            if(p_bar_low < p_array_value)
              {
               _continue_b = true;
               break;
              }
           }

         if(_continue_b)
            continue;

         // Looping though XB Array to find lower point in price than XB value
         for(int xb_idx = 0 ; xb_idx < bars_x_b; xb_idx++)
           {
            int real_b_idx = x_idx - xb_idx - 1 ;
            double b_bar_low = iLow(_Symbol, _Period, real_b_idx);
            double b_array_value = XBArray[xb_idx];

            if(b_bar_low < b_array_value)
              {
               _continue_b = true;
               break;
              }
           }

         if(_continue_b)
            continue;

         // adding B to struct
         my_wave_struct.b_idx = b_idx;
         my_wave_struct.b_price = b_price;

         // adding P to struct
         my_wave_struct.p_idx = p_idx;
         my_wave_struct.p_price = p_price;

         // ===================
         // Calculation A Point
         // ===================

         // Making the array of A and B difference
         double ab_diff_array[];
         for(int ab_idx = 0; ab_idx < bars_x_b; ab_idx++)
           {
            double ab_diff = iHigh(_Symbol, _Period, x_idx - ab_idx) - XBArray[ab_idx];
            append_double(ab_diff_array,  ab_diff);
           }

         int a_idx =  x_idx - ArrayMaximum(ab_diff_array);
         double a_price = iHigh(_Symbol, _Period, a_idx);

         // Filtering b with Min and Max percentage
         double max_val = x_price + (a_price - x_price) * x_to_a_b_max * 0.01;
         double min_val = x_price + (a_price - x_price) * x_to_a_b_min * 0.01;

         if(b_price > max_val || b_price < min_val)
            continue;

         // Checking for a new high between a and b idx if b > x
         int _tmp_a_idx = a_idx;
         if(b_price > x_price)
           {
            for(int high_a = a_idx; high_a > b_idx; high_a--)
              {
               double high_a_price = iHigh(_Symbol, _Period, high_a);
               if(high_a_price > a_price)
                 {
                  _tmp_a_idx = high_a;
                  a_price = high_a_price;
                 }
              }
           }

         // Checking for a new high between x and a idx if b < x
         else
           {
            for(int high_a = x_idx ; high_a >= a_idx; high_a--)
              {
               double high_a_price = iHigh(_Symbol, _Period, high_a);
               if(high_a_price > a_price)
                 {
                  _tmp_a_idx = high_a;
                  a_price = high_a_price;
                 }
              }
           }
         a_idx = _tmp_a_idx;

         // calculating Dynamic width size
         int dynamic_candles_count = b_start_idx - b_idx;
         double increasing_width_value = ((int)(dynamic_candles_count / every_increasing_of_value) + 1) * width_increasing_percentage_x_to_b;
         dynamic_max_width_percentage = max_width_percentage + increasing_width_value;
         dynamic_min_width_percentage = min_width_percentage + increasing_width_value;

         // calculating vertical range for A
         double z = XBArray[x_idx - a_idx];
         double a_upper_boundary = (z * dynamic_max_width_percentage * 0.01) + z;
         double a_lower_boundary = (z * dynamic_min_width_percentage * 0.01) + z;
         if(a_price > a_upper_boundary || a_price < a_lower_boundary)
            continue;


         // adding A to struct
         my_wave_struct.a_idx = a_idx;
         my_wave_struct.a_price = a_price;

         if(pattern_type == X_A_B)
           {
            // checking divergence
            if(!divergence_filter(x_idx, a_idx, b_idx, -1))
               continue;

            // checking tickchart speed
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

         // ===================
         // Calculating C Point
         // ===================

         int c_min_idx = a_idx - (int)(bars_x_b * min_a_to_c_btw_x_b * 0.01);
         int c_max_idx = a_idx - (int)(bars_x_b * max_a_to_c_btw_x_b * 0.01);
         if(c_min_idx >= b_idx)
            c_min_idx = b_idx - 1;

         // Continuation of xb line
         double BCArray[];
         for(int bc_idx = 1; bc_idx <= b_idx - c_max_idx; bc_idx++)
           {
            append_double(BCArray, b_price +  bc_idx * StepXB);
           }

         //Check if C inside the percentage levels from AB leg
         double c_upper_boundary = b_price + (a_price - b_price) * max_width_c_ab * 0.01;
         double c_lower_boundary = b_price + (a_price - b_price) * min_width_c_ab * 0.01;

         //Check if C inside the percentage levels from XA leg
         double c_upper_boundary_xa = x_price + (a_price - x_price) * max_width_c_xa * 0.01;
         double c_lower_boundary_xa = x_price + (a_price - x_price) * min_width_c_xa * 0.01;

         // Loop for C indside B
         for(int c_idx = c_min_idx; c_idx > c_max_idx; c_idx--)
           {
            bool _continue_c = false;
            double current_c_low = iLow(_Symbol, _Period, c_idx);
            double c_price = iHigh(_Symbol, _Period, c_idx);
            int bars_a_c = a_idx - c_idx;

            // Checking if c price is higher than  ac array
            for(int i = 0; i < b_idx - c_idx; i++)
              {
               double tmp_low = iLow(_Symbol, _Period, b_idx - i - 1);
               double tmp_bc_val = BCArray[i];
               if(tmp_low < tmp_bc_val)
                 {
                  _continue_c = true;
                  break;
                 }
              }

            if(_continue_c)
               continue;

            // Check if C inside the percentage levels from AB leg
            if(c_price > c_upper_boundary || c_price < c_lower_boundary)
              {
               continue;
              }

            // Check if C inside the percentage levels from AB leg
            if(c_price > c_upper_boundary_xa || c_price < c_lower_boundary_xa)
              {
               continue;
              }

            // making the array of AC
            double StepAC = (c_price - a_price) / bars_a_c;
            double ACArray[];
            double New_ACArray[]; // ACArray with dynamic size added
            for(int j = 1; j <= bars_a_c; j++)
              {
               int idx = (int)((b_start_idx - b_idx) / every_increasing_of_value);
               double real_ac_val = (a_price + j * StepAC);
               append_double(ACArray, real_ac_val);
               append_double(New_ACArray, real_ac_val + real_ac_val * idx * width_increasing_percentage_a_e * 0.01);
              }

            // Checking if c price is higher than new ac array
            for(int i = 0; i < bars_a_c; i++)
              {
               double new_ac_array_val = New_ACArray[i];
               double temp_c_val = iHigh(_Symbol, _Period, a_idx - i - 1);
               if(temp_c_val > new_ac_array_val)
                 {
                  _continue_c = true;
                  break;
                 }
              }

            if(_continue_c)
               continue;

            // adding C to struct
            my_wave_struct.c_idx = c_idx;
            my_wave_struct.c_price = c_price;

            if(pattern_type == X_A_B_C)
              {
               // checking divergence
               if(!divergence_filter(a_idx, b_idx, c_idx, 1))
                  continue;

               // checking tickchart speed
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

            // ===================
            // Calculating D Point
            // ===================

            int d_min_idx = b_idx - (int)(bars_x_b * min_b_to_d_btw_x_b * 0.01);
            int d_max_idx = b_idx - (int)(bars_x_b * max_b_to_d_btw_x_b * 0.01);
            if(d_min_idx >= c_idx)
               d_min_idx = c_idx - 1;

            // Continuation of ac line
            double ACArrayExt[];
            for(int i = 1; i <= b_idx - d_max_idx; i++)
              {
               append_double(ACArrayExt, c_price +  i * StepAC);
              }

            //Check if D inside the percentage levels from BC leg
            double d_upper_boundary_bc = b_price + (c_price - b_price) * max_width_d_bc * 0.01;
            double d_lower_boundary_bc = b_price + (c_price - b_price) * min_width_d_bc * 0.01;

            //Check if D inside the percentage levels from XA leg
            double d_upper_boundary_xa = x_price + (a_price - x_price) * max_width_d_xa * 0.01;
            double d_lower_boundary_xa = x_price + (a_price - x_price) * min_width_d_xa * 0.01;

            // Loop for D indside C
            for(int d_idx = d_min_idx; d_idx > d_max_idx; d_idx--)
              {

               bool _continue_d = false;
               double current_d_low = iLow(_Symbol, _Period, d_idx);
               double d_price = iLow(_Symbol, _Period, d_idx);
               int bars_b_d = b_idx - d_idx;

               // Checking if d price is higher than new ac array
               for(int i = 0; i < c_idx - d_idx; i++)
                 {
                  double tmp_high = iHigh(_Symbol, _Period, c_idx - i - 1);
                  double tmp_ac_val = ACArrayExt[i];
                  if(tmp_high > tmp_ac_val)
                    {
                     _continue_d = true;
                     break;
                    }
                 }

               if(_continue_d)
                  continue;

               // Check if D inside the percentage levels from BC leg
               if(d_price > d_upper_boundary_bc || d_price < d_lower_boundary_bc)
                 {
                  continue;
                 }

               // Check if D inside the percentage levels from XA leg
               if(d_price > d_upper_boundary_xa || d_price < d_lower_boundary_xa)
                 {
                  continue;
                 }

               // making the array of BD
               double StepBD = (d_price - b_price) / bars_b_d;
               double BDArray[];
               double New_BDArray[]; // ACArray with dynamic size added
               for(int j = 1; j <= bars_b_d; j++)
                 {
                  int idx = (int)((b_start_idx - b_idx) / every_increasing_of_value);
                  double real_bd_val = (b_price + j * StepBD);
                  append_double(BDArray, real_bd_val);
                  append_double(New_BDArray, real_bd_val - real_bd_val * idx * width_increasing_percentage_a_e * 0.01);
                 }

               // Checking if D price is lower than new BD array
               for(int i = 0; i < bars_b_d; i++)
                 {
                  double new_bd_array_val = New_BDArray[i];
                  double temp_d_val = iLow(_Symbol, _Period, b_idx - i - 1);
                  if(temp_d_val < new_bd_array_val)
                    {
                     _continue_d = true;
                     break;
                    }
                 }

               if(_continue_d)
                  continue;

               // adding D to struct
               my_wave_struct.d_idx = d_idx;
               my_wave_struct.d_price = d_price;

               if(pattern_type == X_A_B_C_D)
                 {
                  // checking divergence
                  if(!divergence_filter(b_idx, c_idx, d_idx, -1))
                     continue;

                  // checking tickchart speed
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

               // ===================
               // Calculating E Point
               // ===================

               int e_min_idx = c_idx - (int)(bars_x_b * min_c_to_e_btw_x_b * 0.01);
               int e_max_idx = c_idx - (int)(bars_x_b * max_c_to_e_btw_x_b * 0.01);
               if(e_min_idx >= d_idx)
                  e_min_idx = d_idx - 1;

               // Continuation of BD line
               double BDArrayExt[];
               for(int i = 1; i <= d_idx - e_max_idx; i++)
                 {
                  append_double(BDArrayExt, d_price +  i * StepBD);
                 }

               //Check if E inside the percentage levels from CD leg
               double e_upper_boundary_cd = d_price + (c_price - d_price) * max_width_e_cd * 0.01;
               double e_lower_boundary_cd = d_price + (c_price - d_price) * min_width_e_cd * 0.01;

               //Check if E inside the percentage levels from CD leg
               double e_upper_boundary_xa = x_price + (a_price - x_price) * max_width_e_xa * 0.01;
               double e_lower_boundary_xa = x_price + (a_price - x_price) * min_width_e_xa * 0.01;

               // Loop for E indside D
               for(int e_idx = e_min_idx; e_idx > e_max_idx; e_idx--)
                 {

                  bool _continue_e = false;
                  double current_e_low = iLow(_Symbol, _Period, e_idx);
                  double e_price = iHigh(_Symbol, _Period, e_idx);
                  int bars_c_e = c_idx - e_idx;

                  // Checking if e price is lower than new array
                  for(int i = 0; i < d_idx - e_idx; i++)
                    {
                     double tmp_low = iLow(_Symbol, _Period, d_idx - i - 1);
                     double tmp_bd_val = BDArrayExt[i];
                     if(tmp_low < tmp_bd_val)
                       {
                        _continue_e = true;
                        break;
                       }
                    }

                  if(_continue_e)
                     continue;

                  // Check if E inside the percentage levels from CD leg
                  if(e_price > e_upper_boundary_cd || e_price < e_lower_boundary_cd)
                    {
                     continue;
                    }

                  // Check if E inside the percentage levels from XA leg
                  if(e_price > e_upper_boundary_xa || e_price < e_lower_boundary_xa)
                    {
                     continue;
                    }

                  // making the array of CE
                  double StepCE = (e_price - c_price) / bars_c_e;
                  double CEArray[];
                  double New_CEArray[]; // CEArray with dynamic size added
                  for(int j2 = 1; j2 <= bars_c_e; j2++)
                    {
                     int idx = (int)((b_start_idx - b_idx) / every_increasing_of_value);
                     double real_ce_val = (c_price + j2 * StepCE);
                     append_double(CEArray, real_ce_val);
                     append_double(New_CEArray, real_ce_val + real_ce_val * idx * width_increasing_percentage_a_e * 0.01);
                    }

                  // Checking if E price is higher than new CE array
                  for(int i = 0; i < bars_c_e; i++)
                    {
                     double new_ce_array_val = New_CEArray[i];
                     double temp_e_val = iHigh(_Symbol, _Period, c_idx - i - 1);
                     if(temp_e_val > new_ce_array_val)
                       {
                        _continue_e = true;
                        break;
                       }
                    }

                  if(_continue_e)
                     continue;

                  // adding E to struct
                  my_wave_struct.e_idx = e_idx;
                  my_wave_struct.e_price = e_price;

                  if(pattern_type == X_A_B_C_D_E)
                    {
                     // checking divergence
                     if(!divergence_filter(c_idx, d_idx, e_idx, 1))
                        continue;

                     // checking tickchart speed
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
//|                                                                  |
//+------------------------------------------------------------------+
void phase_two(pattern_type_enum _type, wave_struct& _wave_struct)
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


   if(_type == X_A_B)
     {
      // making XB array
      int bars_x_b = x_idx - b_idx;
      double StepXB = (b_price - x_price) / bars_x_b ;
      double XBArray[];
      for(int i = 0; i < bars_x_b; i++)
        {
         append_double(XBArray, x_price + i * StepXB);
        }


      // Naming Z
      double z_price = XBArray[x_idx - a_idx];
      int z_idx = a_idx;

      //set starting point
      double sp_price = a_price;
      int sp_idx = a_idx;

      int idxs_above_fg[];
      int idxs_below_fg[];
      double FGArray[];
      double f_price;
      int f_idx;
      int bars_f_g;
      for(int q = 0; q <= (int)((100 - f_percentage) / fg_increasing_percentage) + 1; q++)
        {
         ArrayFree(idxs_above_fg);
         ArrayFree(idxs_below_fg);
         ArrayFree(FGArray);

         double p_to_check = f_percentage + q * fg_increasing_percentage;
         if(p_to_check > 100)
            p_to_check = 100;

         // F point price. the point that parallel line to XB starts from
         f_price  = z_price + (a_price - z_price) * p_to_check * 0.01;
         f_idx = z_idx;

         // Making FG array. the line paralel to XA/BD
         double StepFG = StepXB ;
         bars_f_g = f_idx - b_idx;
         for(int i = 0; i <= bars_f_g; i++)
           {
            append_double(FGArray, f_price + i * StepFG);
           }

         double _last_bar_limit  = iHigh(_Symbol, _Period, b_idx);
         if(_last_bar_limit >= FGArray[ArraySize(FGArray) - 1])
            continue;

         // findidng the indices above and below fg line
         for(int i = 0; i <= sp_idx - b_idx; i++)
           {
            double _tmp_p = iHigh(_Symbol, _Period, sp_idx - i);
            double _tmp_fg = FGArray[i];
            if(_tmp_p >= _tmp_fg)
               append_int(idxs_above_fg, i);
            else
               append_int(idxs_below_fg, i);
           }

         if(ArraySize(idxs_above_fg) == 0 || ArraySize(idxs_below_fg) == 0)
            continue;

         int bars_sp_b = sp_idx - b_idx;
         for(int j = (int)(first_line_percentage / first_line_decrease_percentage)  ; j >= 0 ; j--)
           {
            // Making first line array
            double FirstLineArray[];
            double _slope = (sp_price * (first_line_percentage - j * first_line_decrease_percentage) * 0.01) / (sp_idx - b_idx);
            for(int i = 0; i <= sp_idx - b_idx; i++)
              {
               double _tmp_  = sp_price -  _slope * i ;
               append_double(FirstLineArray, _tmp_);
              }

            // different between highs and slope line array for above price
            double above_diff_array[];
            int above_diff_idx_array[];
            for(int i = 0; i < ArraySize(idxs_above_fg); i++)
              {
               int _idx = idxs_above_fg[i];
               append_double(above_diff_array, iHigh(_Symbol, _Period, sp_idx - _idx) - FirstLineArray[_idx]);
               append_int(above_diff_idx_array, _idx);
              }

            // different between highs and slope line array for below price
            double below_diff_array[];
            int below_diff_idx_array[];
            for(int i = 0; i < ArraySize(idxs_below_fg); i++)
              {
               int _idx = idxs_below_fg[i];
               append_double(below_diff_array, iHigh(_Symbol, _Period, sp_idx - _idx) - FirstLineArray[_idx]);
               append_int(below_diff_idx_array, _idx);
              }

            // Finding max in above diff and max in below diff
            double max_above_diff = above_diff_array[ ArrayMaximum(above_diff_array) ] ;
            double max_below_diff = below_diff_array[ ArrayMaximum(below_diff_array) ] ;

            if(max_below_diff < 0 || max_above_diff < 0)
               continue;

            // M N differnce percentage
            double max_diff_percentage;
            //if(max_below_diff == 0)
            //   max_diff_percentage = 0;
            //else
            max_diff_percentage = MathAbs(max_above_diff - max_below_diff) / MathAbs(a_price - b_price);

            // MN found making the extension
            int max_above_idx = sp_idx - above_diff_idx_array[ ArrayMaximum(above_diff_array) ] ;
            int max_below_idx = sp_idx - below_diff_idx_array[ ArrayMaximum(below_diff_array) ] ;


            if(MathAbs(max_above_idx - max_below_idx) < mn_length_percent * 0.01 * (a_idx - b_idx))
               continue;

            double max_above_price = iHigh(_Symbol, _Period, max_above_idx);
            double max_below_price = iHigh(_Symbol, _Period, max_below_idx);
            if(max_diff_percentage > maxBelow_maxAbove_diff_percentage * 0.01 && max_diff_percentage != 1.0)
               continue;


            if(max_below_price > max_above_price)
               continue;

            if(max_below_idx >= max_above_idx)
               continue;

            double StepMN = (max_below_price - max_above_price) / (max_above_idx - max_below_idx);
            double MNArray[];
            max_above_price = max_above_price + (max_above_price - max_below_price) * mn_buffer_percent * 0.01 ;
            for(int i = 0 ; i < max_above_idx - b_idx + mn_extension_bars; i++)
              {
               append_double(MNArray, max_above_price + i * StepMN);
              }

            // Trend line found . searching for breakout from that line
            double phase2Array[];
            int phase2Idx;
            ArrayCopy(phase2Array, MNArray);
            phase2Idx = max_above_idx;

            // making XB Extension array
            double XBExtArray[];
            ArrayCopy(XBExtArray, XBArray);
            for(int i = 0; i <= mn_extension_bars; i++)
              {
               append_double(XBExtArray, b_price + i * StepXB);
              }

            // looping for after D
            for(int i = 1; i < mn_extension_bars; i++)
              {
               int real_idx = b_idx - i;

               if(real_idx < 1)
                  break;

               double trend_price = MNArray[phase2Idx - b_idx + i];
               double ext_price = XBExtArray[x_idx - b_idx + i];
               double _high = mrate[real_idx].high;
               double _low = mrate[real_idx].low;
               double _open = mrate[real_idx].open;
               double _close = mrate[real_idx].close;

               double _break_price;
               if(extension_break_close)
                  _break_price = _close;
               else
                  _break_price = _low;

               if(_break_price < ext_price)
                  break;

               if(_close <= trend_price)
                  continue;

               if(!filter_candle_pattern(1, real_idx))
                  continue;

               //found. drawing arrow
               draw_arrow("buy", real_idx, _low);
               handle_signal(real_idx, 1, _type, _wave_struct);
               break;
              }

            if(draw_lines)
              {
               if(draw_mn)
                  draw_line("mn ext", 0, max_above_idx, max_above_price, b_idx - mn_extension_bars, MNArray[mn_extension_bars + max_above_idx - b_idx - 1], mn_color);
               if(draw_fg)
                  draw_line("fg", 0, f_idx, FGArray[0], b_idx, FGArray[ ArraySize(FGArray) - 1 ], fg_color);
               if(draw_slope)
                  draw_line("first", 0, sp_idx, FirstLineArray[0], b_idx, FirstLineArray[ ArraySize(FirstLineArray) - 1 ], slope_color);
              }
            return;

           }
        }

     }


   if(_type == X_A_B_C)
     {

      // making AC array
      int bars_a_c = a_idx - c_idx;
      double StepAC = (c_price - a_price) / bars_a_c ;
      double ACArray[];
      for(int i = 0; i < bars_a_c; i++)
        {
         append_double(ACArray, a_price + i * StepAC);
        }

      // set starting point
      double sp_price = b_price;
      int sp_idx = b_idx;

      // Naming Z Point:
      double z_price = ACArray[a_idx - b_idx];
      int z_idx = b_idx;

      int idxs_above_fg[];
      int idxs_below_fg[];
      double FGArray[];
      double f_price;
      int f_idx;
      int bars_f_g;

      for(int q = 0; q <= (int)((100 - f_percentage) / fg_increasing_percentage) + 1; q++)
        {
         ArrayFree(idxs_above_fg);
         ArrayFree(idxs_below_fg);
         ArrayFree(FGArray);

         double p_to_check = f_percentage + q * fg_increasing_percentage;
         if(p_to_check > 100)
            p_to_check = 100;

         // F point price. the point that parallel line to AC starts from
         f_price = z_price - (z_price - b_price) * p_to_check * 0.01;
         f_idx =  z_idx;

         // Making FG array. the line paralel to AE/CE
         double StepFG = StepAC;
         bars_f_g = f_idx - c_idx;
         for(int i = 0 ; i <= bars_f_g; i++)
           {
            append_double(FGArray, f_price + i * StepFG);
           }


         double _last_bar_limit  = iLow(_Symbol, _Period, c_idx);
         if(_last_bar_limit <= FGArray[ArraySize(FGArray) - 1])
            continue;

         // findidng the indices above and below fg line
         for(int i = 0; i <= sp_idx - c_idx; i++)
           {
            double _tmp_p = iLow(_Symbol, _Period, sp_idx - i);
            double _tmp_fg = FGArray[i];
            if(_tmp_p > _tmp_fg)
               append_int(idxs_above_fg, i);
            else
               append_int(idxs_below_fg, i);
           }

         if(ArraySize(idxs_above_fg) == 0 || ArraySize(idxs_below_fg) == 0)
            continue;

         //---
         int bars_sp_c = sp_idx - c_idx;
         for(int j = (int)(first_line_percentage / first_line_decrease_percentage)  ; j >= 0 ; j--)
           {
            // Making firs line array
            double FirstLineArray[];
            double _slope = (sp_price * (first_line_percentage - j * first_line_decrease_percentage) * 0.01) / (sp_idx - c_idx);
            for(int i = 0; i <= sp_idx - c_idx; i++)
              {
               double _tmp_  = sp_price +  _slope * i ;
               append_double(FirstLineArray, _tmp_);
              }

            // different between highs and slope line array for above price
            double above_diff_array[];
            int above_diff_idx_array[];
            for(int i = 0; i < ArraySize(idxs_above_fg); i++)
              {
               int _idx = idxs_above_fg[i];
               append_double(above_diff_array, FirstLineArray[_idx] - iLow(_Symbol, _Period, sp_idx - _idx));
               append_int(above_diff_idx_array, _idx);
              }

            // different between highs and slope line array for below price
            double below_diff_array[];
            int below_diff_idx_array[];
            for(int i = 0; i < ArraySize(idxs_below_fg); i++)
              {
               int _idx = idxs_below_fg[i];
               append_double(below_diff_array, FirstLineArray[_idx] - iLow(_Symbol, _Period, sp_idx - _idx));
               append_int(below_diff_idx_array, _idx);
              }

            // Finding max in above diff and max in below diff
            double max_above_diff = above_diff_array[ ArrayMaximum(above_diff_array) ] ;
            double max_below_diff = below_diff_array[ ArrayMaximum(below_diff_array) ] ;

            if(max_below_diff < 0 || max_above_diff < 0)
               continue;

            // M N differnce percentage
            double max_diff_percentage;
            max_diff_percentage = MathAbs(max_above_diff - max_below_diff) / MathAbs(b_price - c_price);

            // MN found making the extension
            int max_above_idx = sp_idx - above_diff_idx_array[ ArrayMaximum(above_diff_array) ] ;
            int max_below_idx = sp_idx - below_diff_idx_array[ ArrayMaximum(below_diff_array) ] ;

            if(MathAbs(max_above_idx - max_below_idx) < mn_length_percent * 0.01 * (b_idx - c_idx))
               continue;

            double max_above_price = iLow(_Symbol, _Period, max_above_idx);
            double max_below_price = iLow(_Symbol, _Period, max_below_idx);
            if(max_diff_percentage > maxBelow_maxAbove_diff_percentage * 0.01 && max_diff_percentage != 1.0)
               continue;

            if(max_below_price > max_above_price)
               continue;

            if(max_below_idx <= max_above_idx)
               continue;

            double StepMN = (max_above_price - max_below_price) / (max_below_idx - max_above_idx);
            double MNArray[];
            max_below_price = max_below_price - (max_above_price - max_below_price) * mn_buffer_percent * 0.01 ;
            for(int i = 0 ; i < max_below_idx - c_idx + mn_extension_bars; i++)
              {
               append_double(MNArray, max_below_price + i * StepMN);
              }

            // Trend line found . searching for breakout from that line
            double phase2Array[];
            int phase2Idx;
            ArrayCopy(phase2Array, MNArray);
            phase2Idx = max_below_idx;

            // making AE Extension array
            double ACExtArray[];
            ArrayCopy(ACExtArray, ACArray);
            for(int i = 0; i <= mn_extension_bars; i++)
              {
               append_double(ACExtArray, c_price + i * StepAC);
              }

            // looping for after D
            for(int i = 1; i < mn_extension_bars; i++)
              {
               int real_idx = c_idx - i;

               if(real_idx < 1)
                  break;

               double trend_price = MNArray[phase2Idx - c_idx + i];
               double ext_price = ACExtArray[a_idx - c_idx + i];
               double _high = mrate[real_idx].high;
               double _low = mrate[real_idx].low;
               double _open = mrate[real_idx].open;
               double _close = mrate[real_idx].close;

               double _break_price;
               if(extension_break_close)
                  _break_price = _close;
               else
                  _break_price = _high;

               if(_break_price > ext_price)
                  break;

               if(_close >= trend_price)
                  continue;

               if(!filter_candle_pattern(-1, real_idx))
                  continue;

               //found. drawing arrow
               draw_arrow("sell", real_idx, _high);
               handle_signal(real_idx, -1, _type, _wave_struct);
               break;
              }

            if(draw_lines)
              {
               if(draw_mn)
                  draw_line("mn ext", 0, max_below_idx, max_below_price, c_idx - mn_extension_bars + 1, MNArray[mn_extension_bars + max_below_idx - c_idx - 1], mn_color);
               if(draw_fg)
                  draw_line("fg", 0, f_idx, FGArray[0], c_idx, FGArray[ ArraySize(FGArray) - 1 ], fg_color);
               if(draw_slope)
                  draw_line("first", 0, sp_idx, FirstLineArray[0], c_idx, FirstLineArray[ ArraySize(FirstLineArray) - 1 ], slope_color);
              }
            return;
           }
        }
     }


   if(_type == X_A_B_C_D)
     {
      // making XD array
      int bars_x_d = x_idx - d_idx;
      double StepXD = (d_price - x_price) / bars_x_d ;
      double XDArray[];
      for(int i = 0; i < bars_x_d; i++)
        {
         append_double(XDArray, x_price + i * StepXD);
        }

      // making BD array
      int bars_b_d = b_idx - d_idx;
      double StepBD = (d_price - b_price) / bars_b_d ;
      double BDArray[];
      for(int i = 0; i < bars_b_d; i++)
        {
         append_double(BDArray, b_price + i * StepBD);
        }

      // checking if B is lower than XD
      bool b_is_lower = false;
      if(b_price < XDArray[x_idx - b_idx])
        {
         b_is_lower = true;
        }

      // Naming Z and Y Point:
      double z_price;
      int z_idx;
      double sp_price;
      int sp_idx;
      sp_price = c_price;
      sp_idx = c_idx;

      if(b_is_lower)
        {
         z_price = BDArray[b_idx - c_idx - 1];
         z_idx = c_idx;
        }
      else
        {
         z_price = XDArray[x_idx - c_idx - 1];
         z_idx = c_idx;
        }

      int idxs_above_fg[];
      int idxs_below_fg[];
      double FGArray[];
      double f_price;
      int f_idx;
      int bars_f_g;
      for(int q = 0; q <= (int)((100 - f_percentage) / fg_increasing_percentage) + 1; q++)
        {
         ArrayFree(idxs_above_fg);
         ArrayFree(idxs_below_fg);
         ArrayFree(FGArray);

         double p_to_check = f_percentage + q * fg_increasing_percentage;
         if(p_to_check > 100)
            p_to_check = 100;


         // F point price. the point that parallel line to AC starts from
         f_price = z_price + (c_price - z_price) * p_to_check * 0.01;
         f_idx =  z_idx;

         // Making FG array. the line paralel to XA/BD
         double StepFG = b_is_lower ? StepBD : StepXD ;
         bars_f_g = f_idx - d_idx;
         for(int i = 0; i <= bars_f_g; i++)
           {
            append_double(FGArray, f_price + i * StepFG);
           }

         double _last_bar_limit  = iHigh(_Symbol, _Period, d_idx);
         if(_last_bar_limit >= FGArray[ArraySize(FGArray) - 1])
            continue;

         // findidng the indices above and below fg line
         for(int i = 0; i <= sp_idx - d_idx; i++)
           {
            double _tmp_p = iHigh(_Symbol, _Period, sp_idx - i);
            double _tmp_fg = FGArray[i];
            if(_tmp_p >= _tmp_fg)
               append_int(idxs_above_fg, i);
            else
               append_int(idxs_below_fg, i);
           }

         if(ArraySize(idxs_above_fg) == 0 || ArraySize(idxs_below_fg) == 0)
            continue;

         //---
         int bars_sp_d = sp_idx - d_idx;
         for(int j = (int)(first_line_percentage / first_line_decrease_percentage)  ; j >= 0 ; j--)
           {
            // Making firs line array
            double FirstLineArray[];
            double _slope = (sp_price * (first_line_percentage - j * first_line_decrease_percentage) * 0.01) / (sp_idx - d_idx);
            for(int i = 0; i <= sp_idx - d_idx; i++)
              {

               double _tmp_  = sp_price -  _slope * i ;
               append_double(FirstLineArray, _tmp_);
              }

            // different between highs and slope line array for above price
            double above_diff_array[];
            int above_diff_idx_array[];
            for(int i = 0; i < ArraySize(idxs_above_fg); i++)
              {
               int _idx = idxs_above_fg[i];
               append_double(above_diff_array, iHigh(_Symbol, _Period, sp_idx - _idx) - FirstLineArray[_idx]);
               append_int(above_diff_idx_array, _idx);
              }

            // different between highs and slope line array for below price
            double below_diff_array[];
            int below_diff_idx_array[];
            for(int i = 0; i < ArraySize(idxs_below_fg); i++)
              {
               int _idx = idxs_below_fg[i];
               append_double(below_diff_array, iHigh(_Symbol, _Period, sp_idx - _idx) - FirstLineArray[_idx]);
               append_int(below_diff_idx_array, _idx);
              }

            // Finding max in above diff and max in below diff
            double max_above_diff = above_diff_array[ ArrayMaximum(above_diff_array) ] ;
            double max_below_diff = below_diff_array[ ArrayMaximum(below_diff_array) ] ;

            if(max_below_diff < 0 || max_above_diff < 0)
               continue;

            // M N differnce percentage
            double max_diff_percentage;
            max_diff_percentage = MathAbs(max_above_diff - max_below_diff) / MathAbs(c_price - d_price);

            // MN found making the extension
            int max_above_idx = sp_idx - above_diff_idx_array[ ArrayMaximum(above_diff_array) ] ;
            int max_below_idx = sp_idx - below_diff_idx_array[ ArrayMaximum(below_diff_array) ] ;

            if(MathAbs(max_above_idx - max_below_idx) < mn_length_percent * 0.01 * (c_idx - d_idx))
               continue;

            double max_above_price = iHigh(_Symbol, _Period, max_above_idx);
            double max_below_price = iHigh(_Symbol, _Period, max_below_idx);

            if(max_diff_percentage > maxBelow_maxAbove_diff_percentage * 0.01 && max_diff_percentage != 1.0)
               continue;

            if(max_below_price > max_above_price)
               continue;

            if(max_below_idx >= max_above_idx)
               continue;

            double StepMN = (max_below_price - max_above_price) / (max_above_idx - max_below_idx);
            double MNArray[];
            max_above_price = max_above_price + (max_above_price - max_below_price) * mn_buffer_percent * 0.01 ;
            for(int i = 0 ; i < max_above_idx - d_idx + mn_extension_bars; i++)
              {
               append_double(MNArray, max_above_price + i * StepMN);
              }

            // Trend line found . searching for breakout from that line
            double phase2Array[];
            int phase2Idx;
            ArrayCopy(phase2Array, MNArray);
            phase2Idx = max_above_idx;

            // making XD Extension array
            double XDExtArray[];
            ArrayCopy(XDExtArray, XDArray);
            for(int i = 0; i <= mn_extension_bars; i++)
              {
               append_double(XDExtArray, d_price + i * StepXD);
              }

            // making BD Extension array
            double BDExtArray[];
            ArrayCopy(BDExtArray, BDArray);
            for(int i = 0; i <= mn_extension_bars; i++)
              {
               append_double(BDExtArray, d_price + i * StepBD);
              }

            // looping for after D
            for(int i = 1; i < mn_extension_bars; i++)
              {
               int real_idx = d_idx - i;

               if(real_idx < 1)
                  break;

               double trend_price = MNArray[phase2Idx - d_idx + i];
               double ext_price = b_is_lower ? BDExtArray[b_idx - d_idx + i] : XDExtArray[x_idx - d_idx + i];
               double _high = mrate[real_idx].high;
               double _low = mrate[real_idx].low;
               double _open = mrate[real_idx].open;
               double _close = mrate[real_idx].close;

               double _break_price;
               if(extension_break_close)
                  _break_price = _close;
               else
                  _break_price = _low;

               if(_break_price < ext_price)
                  break;

               if(_close <= trend_price)
                  continue;

               if(!filter_candle_pattern(1, real_idx))
                  continue;

               //found. drawing arrow
               draw_arrow("buy", real_idx, _low);
               handle_signal(real_idx, 1, _type, _wave_struct);
               break;
              }

            if(draw_lines)
              {
               if(draw_mn)
                  draw_line("mn ext", 0, max_above_idx, max_above_price, d_idx - mn_extension_bars + 1, MNArray[mn_extension_bars + max_above_idx - d_idx - 1], mn_color);
               if(draw_fg)
                  draw_line("fg", 0, f_idx, FGArray[0], d_idx, FGArray[ ArraySize(FGArray) - 1 ], fg_color);
               if(draw_slope)
                  draw_line("first", 0, sp_idx, FirstLineArray[0], d_idx, FirstLineArray[ ArraySize(FirstLineArray) - 1 ], slope_color);
              }
            return;
           }
        }
     }


   if(_type == X_A_B_C_D_E)
     {
      // making AE array
      int bars_a_e = a_idx - e_idx;
      double StepAE = (e_price - a_price) / bars_a_e ;
      double AEArray[];
      for(int i = 0; i < bars_a_e; i++)
        {
         append_double(AEArray, a_price + i * StepAE);
        }

      // making CE array
      int bars_c_e = c_idx - e_idx;
      double StepCE = (e_price - c_price) / bars_c_e ;
      double CEArray[];
      for(int i = 0; i < bars_c_e; i++)
        {
         append_double(CEArray, c_price + i * StepCE);
        }

      // checking if C is higher than AE
      bool c_is_higher = false;
      if(c_price > AEArray[a_idx - c_idx])
        {
         c_is_higher = true;
        }

      // Naming Z and Y Point:
      double z_price;
      int z_idx;
      double sp_price;
      int sp_idx;

      double d_diff = AEArray[a_idx - d_idx] - d_price;
      double b_diff = AEArray[a_idx - b_idx] - b_price;

      double final_diff;
      if(c_is_higher)
        {
         z_price = CEArray[c_idx - d_idx];
         z_idx = d_idx;
         sp_price = d_price;
         sp_idx = d_idx;
         final_diff = z_price - d_price;
        }
      else
        {
         if(d_diff > b_diff)
           {
            z_price = AEArray[a_idx - d_idx];
            z_idx = d_idx;
            sp_price = d_price;
            sp_idx = d_idx;
            final_diff = d_diff;
           }
         else
           {
            z_price = AEArray[a_idx - b_idx];
            z_idx = b_idx;
            sp_price = b_price;
            sp_idx = b_idx;
            final_diff = b_diff;
           }
        }

      int idxs_above_fg[];
      int idxs_below_fg[];
      double FGArray[];
      double f_price;
      int f_idx;
      int bars_f_g;
      for(int q = 0; q <= (int)((100 - f_percentage) / fg_increasing_percentage) + 1; q++)
        {
         ArrayFree(idxs_above_fg);
         ArrayFree(idxs_below_fg);
         ArrayFree(FGArray);

         double p_to_check = f_percentage + q * fg_increasing_percentage;
         if(p_to_check > 100)
            p_to_check = 100;

         // F point price. the point that parallel line to XB starts from
         f_price  = z_price - final_diff * p_to_check * 0.01;
         f_idx = z_idx;

         //draw_line("fg", 0, f_idx, FGArray[0], e_idx, FGArray[ ArraySize(FGArray) - 1 ], fg_color);
         // Making FG array. the line paralel to AE/CE
         double StepFG = c_is_higher ? StepCE : StepAE ;
         bars_f_g = f_idx - e_idx;
         for(int i = 0; i <= bars_f_g; i++)
           {
            append_double(FGArray, f_price + i * StepFG);
           }

         double _last_bar_limit  = iLow(_Symbol, _Period, e_idx);
         if(_last_bar_limit <= FGArray[ArraySize(FGArray) - 1])
            continue;

         // findidng the indices above and below fg line
         for(int i = sp_idx - e_idx ; i >= 0 ; i--)
           {
            double _tmp_p = iLow(_Symbol, _Period, sp_idx - i);
            double _tmp_fg = FGArray[i];
            if(_tmp_p >= _tmp_fg)
               append_int(idxs_above_fg, i);
            else
               append_int(idxs_below_fg, i);
           }


         if(ArraySize(idxs_above_fg) == 0 || ArraySize(idxs_below_fg) == 0)
            continue;

         //---
         int bars_sp_e = sp_idx - e_idx;
         for(int j = (int)(first_line_percentage / first_line_decrease_percentage)  ; j >= 0 ; j--)
           {
            // Making firs line array
            double FirstLineArray[];
            double _slope = (sp_price * (first_line_percentage - j * first_line_decrease_percentage) * 0.01) / (sp_idx - e_idx);
            for(int i = 0; i <= sp_idx - e_idx; i++)
              {
               double _tmp_  = sp_price +  _slope * i ;
               append_double(FirstLineArray, _tmp_);
              }

            // different between highs and slope line array for above price
            double above_diff_array[];
            int above_diff_idx_array[];
            for(int i = 0; i < ArraySize(idxs_above_fg); i++)
              {
               int _idx = idxs_above_fg[i];
               append_double(above_diff_array, FirstLineArray[_idx] - iLow(_Symbol, _Period, sp_idx - _idx));
               append_int(above_diff_idx_array, _idx);
              }

            // different between highs and slope line array for below price
            double below_diff_array[];
            int below_diff_idx_array[];
            for(int i = 0; i < ArraySize(idxs_below_fg); i++)
              {
               int _idx = idxs_below_fg[i];
               append_double(below_diff_array, FirstLineArray[_idx] - iLow(_Symbol, _Period, sp_idx - _idx));
               append_int(below_diff_idx_array, _idx);
              }

            // Finding max in above diff and max in below diff
            double max_above_diff = above_diff_array[ ArrayMaximum(above_diff_array) ] ;
            double max_below_diff = below_diff_array[ ArrayMaximum(below_diff_array) ] ;

            if(max_below_diff < 0 || max_above_diff < 0)
               continue;

            // M N differnce percentage
            double max_diff_percentage;
            max_diff_percentage = MathAbs(max_above_diff - max_below_diff) / MathAbs(d_price - e_price);

            // MN found making the extension
            int max_above_idx = sp_idx - above_diff_idx_array[ ArrayMaximum(above_diff_array) ] ;
            int max_below_idx = sp_idx - below_diff_idx_array[ ArrayMaximum(below_diff_array) ] ;

            if(MathAbs(max_above_idx - max_below_idx) < mn_length_percent * 0.01 * (d_idx - e_idx))
               continue;

            double max_above_price = iLow(_Symbol, _Period, max_above_idx);
            double max_below_price = iLow(_Symbol, _Period, max_below_idx);

            if(max_diff_percentage > maxBelow_maxAbove_diff_percentage * 0.01 && max_diff_percentage != 1.0)
               continue;

            if(max_below_price > max_above_price)
               continue;

            if(max_below_idx <= max_above_idx)
               continue;

            double StepMN = (max_above_price - max_below_price) / (max_below_idx - max_above_idx);
            double MNArray[];
            max_below_price = max_below_price - (max_above_price - max_below_price) * mn_buffer_percent * 0.01 ;
            for(int i = 0 ; i < max_below_idx - e_idx + mn_extension_bars; i++)
              {
               append_double(MNArray, max_below_price + i * StepMN);
              }

            // Trend line found . searching for breakout from that line
            double phase2Array[];
            int phase2Idx;
            ArrayCopy(phase2Array, MNArray);
            phase2Idx = max_below_idx;

            // making AE Extension array
            double AEExtArray[];
            ArrayCopy(AEExtArray, AEArray);
            for(int i = 0; i <= mn_extension_bars; i++)
              {
               append_double(AEExtArray, e_price + i * StepAE);
              }

            // making CE Extension array
            double CEExtArray[];
            ArrayCopy(CEExtArray, CEArray);
            for(int i = 0; i <= mn_extension_bars; i++)
              {
               append_double(CEExtArray, e_price + i * StepCE);
              }

            // looping for after D
            for(int i = 1; i < mn_extension_bars; i++)
              {
               int real_idx = e_idx - i;

               if(real_idx < 1)
                  break;

               double trend_price = MNArray[phase2Idx - e_idx + i];
               double ext_price = c_is_higher ? CEExtArray[c_idx - e_idx + i] : AEExtArray[a_idx - e_idx + i];
               double _high = mrate[real_idx].high;
               double _low = mrate[real_idx].low;
               double _open = mrate[real_idx].open;
               double _close = mrate[real_idx].close;

               double _break_price;
               if(extension_break_close)
                  _break_price = _close;
               else
                  _break_price = _high;

               if(_break_price > ext_price)
                  break;

               if(_close >= trend_price)
                  continue;

               if(!filter_candle_pattern(-1, real_idx))
                  continue;

               //found. drawing arrow
               draw_arrow("sell", real_idx, _high);
               handle_signal(real_idx, -1, _type, _wave_struct);
               break;
              }

            if(draw_lines)
              {
               if(draw_mn)
                  draw_line("mn ext", 0, max_below_idx, max_below_price, e_idx - mn_extension_bars + 1, MNArray[mn_extension_bars + max_below_idx - e_idx - 1], mn_color);
               if(draw_fg)
                  draw_line("fg", 0, f_idx, FGArray[0], e_idx, FGArray[ ArraySize(FGArray) - 1 ], fg_color);
               if(draw_slope)
                  draw_line("first", 0, sp_idx, FirstLineArray[0], e_idx, FirstLineArray[ ArraySize(FirstLineArray) - 1 ], slope_color);

              }
            return;
           }
        }
     }

  }


//+------------------------------------------------------------------+
//| Callback after finishing the pattern calculation
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

      default:
         return;
     }
//ChartRedraw();
   return;
  }


//+------------------------------------------------------------------+
//| Appends double to array
//+------------------------------------------------------------------+
void append_double(double& myarray[], double value)
  {
   ArrayResize(myarray, ArraySize(myarray) + 1);
   myarray[ArraySize(myarray) - 1] = value;
  }


//+------------------------------------------------------------------+
//| Appends int to array
//+------------------------------------------------------------------+
void append_int(int& myarray[], int value)
  {
   ArrayResize(myarray, ArraySize(myarray) + 1);
   myarray[ArraySize(myarray) - 1] = value;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int array_search_int(int& _arr[], int _val)
  {
   for(int i = 0; i < ArraySize(_arr); i++)
     {
      if(_val == _arr[i])
         return i;
     }
   return -1;
  }

//+------------------------------------------------------------------+
//| Function to draw lines
//+------------------------------------------------------------------+
void draw_line(string _name, int x_idx, int idx1, double price1, int idx2, double price2, color _color, int _width = 1, int _style = STYLE_SOLID)
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
   ObjectSetInteger(0, _myname, OBJPROP_STYLE, _style);
   ObjectSetInteger(0, _myname, OBJPROP_WIDTH, _width);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void draw_label(string _name, string _txt, int idx1, int _vert_pos, double _price = 0)
  {
   double price1;
   if(_price == 0)
      price1 = _vert_pos == 1 ? mrate[idx1].high : mrate[idx1].low;
   else
      price1 = _price;

   string salt = (string)MathRand();
   string _myname = Prefix + _name + salt;
   ObjectCreate(0, _myname, OBJ_TEXT, 0, iTime(_Symbol, _Period, idx1), price1);
   ObjectSetString(0, _myname, OBJPROP_TEXT, _txt);
   ObjectSetInteger(0, _myname, OBJPROP_FONTSIZE, label_font_size);
   ObjectSetInteger(0, _myname, OBJPROP_COLOR, label_font_color);
   if(_vert_pos == 1)
      ObjectSetInteger(0, _myname, OBJPROP_ANCHOR, ANCHOR_LOWER);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void draw_progress(string _text, color _clr)
  {
   string _status = Prefix + "status";
   ObjectCreate(0, _status, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, _status, OBJPROP_TEXT, _text);
   ObjectSetInteger(0, _status, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, _status, OBJPROP_YDISTANCE, 30);
   ObjectSetInteger(0, _status, OBJPROP_COLOR, _clr);
//ChartRedraw();
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void update_rates()
  {
   ArraySetAsSeries(mrate,true);
   if(CopyRates(_Symbol,_Period,0, Bars(_Symbol, _Period),mrate) < 0)
      return;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool tick_speed_filter(int idx1, int idx2)
  {
   int seconds1 = int(iTime(_Symbol, _Period, idx2) - iTime(_Symbol, _Period, idx1));
   int bars1 = idx1 - idx2;

   if(seconds1 / bars1 < tick_min_speed)
      return true;

   return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
//|                                                                  |
//+------------------------------------------------------------------+
bool isNewBar()
  {
   static datetime last_time = 0;
   datetime lastbar_time = (datetime)SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);
   if(last_time == 0)
     {
      last_time = lastbar_time;
      return false ;
     }
   if(last_time != lastbar_time)
     {
      last_time = lastbar_time;
      return true ;
     }
   return false ;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool filter_candle_pattern(int _dir, int _idx)
  {

   double _high = mrate[_idx].high;
   double _low = mrate[_idx].low;
   double _open = mrate[_idx].open;
   double _close = mrate[_idx].close;

   double _high_prev = mrate[_idx + 1].high;
   double _low_prev = mrate[_idx + 1].low;
   double _open_prev = mrate[_idx + 1].open;
   double _close_prev = mrate[_idx + 1].close;

   if(filter_candle_direction)
     {
      if(_dir == 1 && _close < _open)
         return false;
      if(_dir == -1 && _close > _open)
         return false;
     }

   if(filter_candle_engulf_close)
     {
      if(_dir == 1 && _close < _high_prev)
         return false;
      if(_dir == -1 && _close > _low_prev)
         return false;
     }

   if(filter_candle_engulf_shadow)
     {
      if(_dir == 1 && _high < _high_prev)
         return false;
      if(_dir == -1 && _low > _low_prev)
         return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool open_new_market(int mode, string _symb, double _lot, double _sl, double _tp, string _sl_tp_mode = "price", string cm = NULL)
  {
// _sl_tp_mode "price" / "point"
   MqlTick latest_price;
   if(!SymbolInfoTick(_symb,latest_price))
      return false;
   double Ask = latest_price.ask;
   double Bid = latest_price.bid;

   double _mysl = 0, _mytp = 0;
   if(_sl_tp_mode == "price")
     {
      _mysl = _sl;
      _mytp = _tp;
     }
   else
     {
      double _p = SymbolInfoDouble(_symb, SYMBOL_POINT);
      if(mode == ORDER_TYPE_BUY)
        {
         _mysl = _sl == 0 ? 0 : Ask - _sl * _p;
         _mytp = _tp == 0 ? 0 : Ask + _tp * _p;
        }
      if(mode == ORDER_TYPE_SELL)
        {
         _mysl = _sl == 0 ? 0 : Bid + _sl * _p;
         _mytp = _tp == 0 ? 0 : Bid - _tp * _p;
        }
     }

   if(mode == ORDER_TYPE_BUY)
     {
      //buy
      bool res = Trade.Buy(NormalizeDouble(_lot, 2), _symb, Ask, _mysl, _mytp, cm);
      if(!res)
        {
         Print(GetLastError());
         return false;
        }
     }

   if(mode == ORDER_TYPE_SELL)
     {
      //sell
      bool res = Trade.Sell(NormalizeDouble(_lot, 2), _symb, Bid, _mysl, _mytp, cm);
      if(!res)
        {
         Print(GetLastError());
         return false;
        }
     }

   Sleep(1000);
   return true;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void first_checks()
  {

  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void close_all()
  {
   MqlTradeRequest req = {TRADE_ACTION_DEAL};
   MqlTradeResult  res = {0};
   req.action = TRADE_ACTION_REMOVE;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      req.order  = OrderGetTicket(i);
      if(!OrderSend(req, res))
        {
         Print("Fail to delete ticket ", req.order, ": Error ", GetLastError(), ", retcode = ", res.retcode);
        }
     }
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionSelectByTicket(PositionGetTicket(i)))
         Trade.PositionClose(PositionGetTicket(i));
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int leg_idx(int shift, pattern_type_enum _type, wave_struct& _wave_struct)
  {
   if(_type == X_A_B)
     {
      if(shift == 0)
         return _wave_struct.b_idx;
      if(shift == 1)
         return _wave_struct.a_idx;
      if(shift == 2)
         return _wave_struct.x_idx;
     }

   if(_type == X_A_B_C)
     {
      if(shift == 0)
         return _wave_struct.c_idx;
      if(shift == 1)
         return _wave_struct.b_idx;
      if(shift == 2)
         return _wave_struct.a_idx;
      if(shift == 3)
         return _wave_struct.x_idx;
     }


   if(_type == X_A_B_C_D)
     {
      if(shift == 0)
         return _wave_struct.d_idx;
      if(shift == 1)
         return _wave_struct.c_idx;
      if(shift == 2)
         return _wave_struct.b_idx;
      if(shift == 3)
         return _wave_struct.a_idx;
      if(shift == 4)
         return _wave_struct.x_idx;
     }

   if(_type == X_A_B_C_D_E)
     {
      if(shift == 0)
         return _wave_struct.e_idx;
      if(shift == 1)
         return _wave_struct.d_idx;
      if(shift == 2)
         return _wave_struct.c_idx;
      if(shift == 3)
         return _wave_struct.b_idx;
      if(shift == 4)
         return _wave_struct.a_idx;
      if(shift == 5)
         return _wave_struct.x_idx;
     }

   return -1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void draw_rectangle(string _name, int idx1, double price1, int idx2, double price2, color _color = clrRed, string prefix = "", bool force_new = false)
  {
   string salt;
   if(force_new)
      salt = (string)MathRand() + (string)MathRand() + (string)MathRand();
   else
      salt = "";
   string _myname = prefix + _name + salt;
   ObjectCreate(0, _myname, OBJ_RECTANGLE, 0, 0, 0,  0, 0);
   ObjectSetInteger(0, _myname, OBJPROP_TIME, 0, iTime(_Symbol, _Period, idx1));
   ObjectSetInteger(0, _myname, OBJPROP_TIME, 1, iTime(_Symbol, _Period, idx2));

   ObjectSetDouble(0, _myname, OBJPROP_PRICE, 0, price1);
   ObjectSetDouble(0, _myname, OBJPROP_PRICE, 1, price2);

   ObjectSetInteger(0, _myname, OBJPROP_COLOR, _color);
   ObjectSetInteger(0, _myname,  OBJPROP_FILL, true);
   ObjectSetInteger(0, _myname,  OBJPROP_BACK, true);
  }


//+------------------------------------------------------------------+
//|    Handles the main signal got from patterns                                                              |
//+------------------------------------------------------------------+
void handle_signal(int _idx, int _mode, pattern_type_enum _type, wave_struct& _wave_struct)
  {

//--- Prev Signal data for simulation
   static int _prev_idx = -1, _prev_mode = -1;
   static ENUM_ORDER_TYPE _prev_order_type = -1;
   static double _prev_stoploss = -1, _prev_takeprofit = -1, _prev_entry_price = -1;

// Skipping the aleady handeled signals
   if(array_search_int(_handled_signals, _idx) != -1)
     {
      return;
     }
   else
      append_int(_handled_signals, _idx);

//---
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double _close = iClose(_Symbol, PERIOD_CURRENT, _idx);
   double _high = iHigh(_Symbol, PERIOD_CURRENT, _idx);
   double _low = iLow(_Symbol, PERIOD_CURRENT, _idx);
   double spread = ask - bid;
//---

// Finding the highest or the lowest price in the last leg
   double _stoploss, _stoploss_dis, _xtreme_price, _initial_stoploss;
   int _xtreme_idx;
   int _last_leg_start_idx = leg_idx(1, _type, _wave_struct);
   int _last_leg_end_idx = leg_idx(0, _type, _wave_struct);

   if(_mode == 1)
     {
      _xtreme_idx = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, _last_leg_start_idx - _idx, _idx);
      _xtreme_price = iLow(_Symbol, PERIOD_CURRENT, _xtreme_idx) ;
     }
   else
     {
      _xtreme_idx = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, _last_leg_start_idx - _idx, _idx);
      _xtreme_price = iHigh(_Symbol, PERIOD_CURRENT, _xtreme_idx);
     }

   _stoploss_dis = _xtreme_price * stoploss_percent * 0.01;

   if(_mode == 1)
     {
      _stoploss = _initial_stoploss = _xtreme_price - _stoploss_dis;
     }
   else
     {
      _stoploss = _initial_stoploss = _xtreme_price + _stoploss_dis;
     }


//--- Entry Level

   double _entry_price;
   double entry_dis = _stoploss * entry_percent_sl * 0.01;
   int xb_len = _wave_struct.x_idx - _wave_struct.b_idx;
   double entry_xb_increase = _stoploss * (xb_len / every_increasing_of_value) * fixed_entry_increase * 0.01;

   if(entry_type == FIXED)
     {
      if(_mode == 1)
        {
         _entry_price = _stoploss + entry_dis + entry_xb_increase;
         if(_close <= _entry_price)
            _entry_price = _close;
        }
      else
        {
         _entry_price = _stoploss - entry_dis - entry_xb_increase;
         if(_close >= _entry_price)
            _entry_price = _close;
        }


     }
   else
     {
      _entry_price = _close;
     }

   double _entry_stoploss_diff = MathAbs(_entry_price - _stoploss);
   double _entry_stoploss_diff_percent = MathAbs(_entry_price - _stoploss) / _stoploss;

// Checking Entry type if entry exceeds the max entry_sl difference
   if(entry_type == MARKET && _entry_stoploss_diff_percent > max_diff_sl_price * 0.01)
     {
      double max_entry_dis  = _stoploss * max_diff_sl_price * 0.01;
      if(stoploss_mode == MARKET_SL)
        {
         if(_mode == 1)
           {
            _stoploss = _entry_price - max_entry_dis;
           }
         else
           {
            _stoploss = _entry_price + max_entry_dis;
           }
        }
      if(stoploss_mode == FIXED_SL)
        {
         // SL is already configured. Changin the Entry Price to be fixed at max_diff
         if(_mode == 1)
           {
            _entry_price = _stoploss + max_entry_dis + entry_xb_increase;
           }
         else
           {
            _entry_price = _stoploss - max_entry_dis  - entry_xb_increase;
           }
        }
      else // REGULAR_MARKET_SL
        {
         // SL already configured at the begining.
         // Leaving entry and the stoploss as before
        }
     }

// Updating parameters
   _entry_stoploss_diff = MathAbs(_entry_price - _stoploss);
   _entry_stoploss_diff_percent = MathAbs(_entry_price - _stoploss) / _stoploss;

//--- Zones
   double _price_stoploss_diff = MathAbs(_entry_price - _initial_stoploss);
   double _price_stoploss_diff_percent = _price_stoploss_diff / _initial_stoploss;
   double _takeprofit, _takeprofit_diff, _takeprofit_times;

   if(_price_stoploss_diff_percent >= diff_sl_price_zone * 0.01)
     {
      double _remain_percent = _price_stoploss_diff_percent - diff_sl_price_zone * 0.01;
      _takeprofit_times = tp_times - (_remain_percent / (diff_increases_sl * 0.01) * tp_decreasing);
     }
   else
     {
      _takeprofit_times = tp_times;
     }

// Min TP Times
   if(_takeprofit_times < min_tp_times)
      _takeprofit_times = min_tp_times;
//--- Rounding TP Times
   _takeprofit_times = NormalizeDouble(_takeprofit_times, 1);
//---
   _takeprofit_diff = _entry_stoploss_diff * _takeprofit_times;

   if(_mode == 1)
     {
      _takeprofit = _entry_price + _takeprofit_diff;
     }
   else
     {
      _takeprofit = _entry_price - _takeprofit_diff;
     }

//--- Drawing final parameters
   draw_line("tp", 0, _xtreme_idx, _takeprofit, _idx, _takeprofit, tp_color, 3);
   draw_label("rr", "RR:" + (string)_takeprofit_times, _xtreme_idx, -1, _takeprofit);
   draw_line("sl", 0, _xtreme_idx, _stoploss, _idx, _stoploss, sl_color, 3);
   draw_line("entry", 0, _xtreme_idx, _entry_price, _idx, _entry_price, entry_color, 3);

//--- Final entry type
   ENUM_ORDER_TYPE _order_type;
   if(_entry_price == _close)
     {
      if(_mode == 1)
         _order_type = ORDER_TYPE_BUY;
      else
         _order_type = ORDER_TYPE_SELL;
     }
   else
     {
      if(_mode == 1 && _entry_price < _close)
         _order_type = ORDER_TYPE_BUY_LIMIT;
      else
         if(_mode == -1 && _entry_price > _close)
            _order_type = ORDER_TYPE_SELL_LIMIT;
         else
           {
            Print("Invalid entry type");
            return;
           }
     }

//-----------------------------------------------------------
//--- Simulating the previous signal to fin the special signal
//-----------------------------------------------------------
//   int _buys_max = 1, _sells_max = 1 ;
//
//   static int _sl_buy_count = 0, _sl_sell_count = 0;
//   bool _buy_order_triggered = false, _sell_order_triggered = false ; // Using this for the limit orders
//   int _trigger_index = -1;
//   static int _prev_end_idx = -1; // The orders opened before the _prev_end_idx will be ignored.
//   static int _buys_open = 0, _sells_open = 0;
//// Checking if the signal is triggered from the prev signal until the current signal
//   if(_prev_idx < _prev_end_idx || _prev_end_idx == -1)
//     {
//      for(int i =  _prev_idx - 1; i > _idx; i--)
//        {
//         double _cur_close = iClose(_Symbol, PERIOD_CURRENT, i);
//         double _cur_high = iHigh(_Symbol, PERIOD_CURRENT, i);
//         double _cur_low = iLow(_Symbol, PERIOD_CURRENT, i);
//         if(_prev_order_type == ORDER_TYPE_BUY || _prev_order_type == ORDER_TYPE_SELL)
//           {
//            if(_prev_mode == 1)
//              {
//               _buy_order_triggered = true;
//               _buys_open++;
//              }
//            else
//              {
//               _sell_order_triggered = true;
//               _sells_open++;
//              }
//
//            _trigger_index = i;
//            draw_label("trigger", "Market trigger", i, -1, _cur_close);
//            break;
//           }
//         else
//           {
//            if(_prev_mode == 1 && _cur_low < _prev_entry_price)
//              {
//               _buy_order_triggered = true;
//               _buys_open++;
//               _trigger_index = i;
//               draw_label("trigger", "Buy Trigger", i, -1, _cur_close);
//               break;
//              }
//            if(_prev_mode == -1 && _cur_high > _prev_entry_price)
//              {
//               _sell_order_triggered = true;
//               _trigger_index = i;
//               _sells_open++;
//               draw_label("trigger", "Sell Trigger", i, -1, _cur_close);
//               break;
//              }
//           }
//        }
//     }
//
//
//   if(_buy_order_triggered)
//     {
//      // Now the signal is triggered. looping to find the sl and tp
//      for(int i = _trigger_index; i > 0; i--)
//        {
//         double _cur_high = iHigh(_Symbol, PERIOD_CURRENT, i);
//         double _cur_low = iLow(_Symbol, PERIOD_CURRENT, i);
//         if(_prev_mode == 1)
//           {
//            if(_cur_high > _prev_takeprofit)
//              {
//               //TP
//               _sl_buy_count = 0;
//               _prev_end_idx = i;
//               draw_label("trigger", "Buy TP", i, -1, _cur_high);
//               draw_line("market", 0, _prev_idx, _prev_entry_price, _trigger_index, _prev_entry_price, sim_tp_line_color, 1, STYLE_DASHDOT);
//               draw_line("market", 0, _trigger_index, _prev_entry_price, _prev_end_idx, _prev_takeprofit, sim_tp_line_color, 1, STYLE_DASHDOT);
//               break;
//              }
//            if(_cur_low < _prev_stoploss)
//              {
//               //SL
//               _sl_buy_count++;
//               _prev_end_idx = i;
//               draw_label("trigger", "Buy SL:" + (string)_sl_buy_count, i, -1, _cur_low);
//               draw_line("market", 0, _prev_idx, _prev_entry_price, _trigger_index, _prev_entry_price, sim_sl_line_color, 1, STYLE_DASHDOT);
//               draw_line("market", 0, _trigger_index, _prev_entry_price, _prev_end_idx, _prev_stoploss, sim_sl_line_color, 1, STYLE_DASHDOT);
//               break;
//              }
//           }
//         else
//           {
//            if(_cur_low < _prev_takeprofit)
//              {
//               // TP
//               _sl_sell_count = 0;
//               _prev_end_idx = i;
//               draw_label("trigger", "Sell TP", i, -1, _cur_low);
//               draw_line("market", 0, _prev_idx, _prev_entry_price, _trigger_index, _prev_entry_price, sim_tp_line_color, 1, STYLE_DASHDOT);
//               draw_line("market", 0, _trigger_index, _prev_entry_price, _prev_end_idx, _prev_takeprofit, sim_tp_line_color, 1, STYLE_DASHDOT);
//               break;
//              }
//            if(_cur_high > _prev_stoploss)
//              {
//               // SL
//               _sl_sell_count++;
//               _prev_end_idx = i;
//               draw_label("trigger", "Sell SL:" + (string)_sl_sell_count, i, -1, _cur_high);
//               draw_line("market", 0, _prev_idx, _prev_entry_price, _trigger_index, _prev_entry_price, sim_sl_line_color, 1, STYLE_DASHDOT);
//               draw_line("market", 0, _trigger_index, _prev_entry_price, _prev_end_idx, _prev_stoploss, sim_sl_line_color, 1, STYLE_DASHDOT);
//               break;
//              }
//           }
//        }
//     }

//--- Filling in the prev signal data
   _prev_idx = _idx;
   _prev_mode = _mode;
   _prev_order_type = _order_type;
   _prev_stoploss = _stoploss;
   _prev_takeprofit = _takeprofit;
   _prev_entry_price = _entry_price;

   ChartRedraw();
  }


//+------------------------------------------------------------------+
