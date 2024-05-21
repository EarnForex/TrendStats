//+------------------------------------------------------------------+
//|                                                   TrendStats.mqh |
//|                             Copyright © 2019-2024, EarnForex.com |
//|                                       https://www.earnforex.com/ |
//+------------------------------------------------------------------+
#property strict

enum period
{
    Last_5_Years,
    Time_Period,
    Last_N_Candles,
};

class TrendStats
{
private:
    period           PeriodToProcess;
    int              N;
    int              MA_Period;
    datetime         GivenStartDate;
    datetime         GivenFinishDate;
    int              Calculated_Time_Shift;
    ENUM_TIMEFRAMES  timeframe;
    string           symbol;

    // Try to copy rates for the given start and finish dates.
    double           close_array[], open_array[], high_array[], low_array[];
    datetime         time_array[];

    bool             print_off;

    void             DoMAComparison(const int i, const double ma, int &cnt_above, int &cnt_below, int &array[], int &j);
    void             DoHHHLLLLHCounting(const int i, int &cnt_HHHL, int &cnt_LLLH, int &array[], int &j);
    void             DoConsBullBearCounting(const int i, int &cnt_Bull, int &cnt_Bear, int &array[], int &j);

public:
                     TrendStats();
                    ~TrendStats() {};
    bool             Initialize(string s, string t, datetime GSD, datetime GFD, period PTP, int n, int CTS, int MAP);
    bool             PrepareData();
    void             SilentMode(bool on)
    {
        print_off = on;
    }

    // Output data
    double           PC_mean, PC_median, PR_mean, PR_median, ABSMA_mean, ABSMA_median, ABEMA_mean, ABEMA_median, HHHLLLLH_mean, ConsBullBear_mean, Spikiness_mean, Spikiness_median;
};

TrendStats::TrendStats()
{
    print_off = false;
}

bool TrendStats::Initialize(string s, string t, datetime GSD, datetime GFD, period PTP, int n, int CTS, int MAP)
{

    symbol = s;
    if ((t == "D1") || (t == "PERIOD_D1")) timeframe = PERIOD_D1;
    else if ((t == "W1") || (t == "PERIOD_W1")) timeframe = PERIOD_W1;
    else if ((t == "MN") || (t == "PERIOD_MN") || (t == "MN1") || (t == "PERIOD_MN1")) timeframe = PERIOD_MN1;
    else if ((t == "H1") || (t == "PERIOD_H1")) timeframe = PERIOD_H1;
    else if ((t == "H4") || (t == "PERIOD_H4")) timeframe = PERIOD_H4;
    else if ((t == "M30") || (t == "PERIOD_M30")) timeframe = PERIOD_M30;
    else if ((t == "M15") || (t == "PERIOD_M15")) timeframe = PERIOD_M15;
    else if ((t == "M5") || (t == "PERIOD_M5")) timeframe = PERIOD_M5;
    else if ((t == "H6") || (t == "PERIOD_H6")) timeframe = PERIOD_H6;
    else if ((t == "H8") || (t == "PERIOD_H8")) timeframe = PERIOD_H8;
    else if ((t == "H12") || (t == "PERIOD_H12")) timeframe = PERIOD_H12;
    else return false;

    GivenStartDate = GSD;
    GivenFinishDate = GFD;
    PeriodToProcess = PTP;
    N = n;
    Calculated_Time_Shift = CTS;
    MA_Period = MAP;

    if (timeframe < PERIOD_H4) Calculated_Time_Shift = 0;
    else if (timeframe == PERIOD_H4) Calculated_Time_Shift = Calculated_Time_Shift % 4;

    return true;
}

bool TrendStats::PrepareData()
{

    if (iBars(symbol, timeframe) < 3) return false; // Not enough bars. 3 because the current one cannot be used (not fully formed yet) and we need at least two to make any comparisons.

    // If Time_Shift is zero, then the indicator can use Period() (current timeframe) to fetch all the data.
    // If Time_Shift is non-zero, then PERIOD_H1 should be used to construct everything.
    // Those are two totally different cases.
    
    // Find given dates for the default 5-year period:
    if (PeriodToProcess == Last_5_Years)
    {
        if (!print_off) Print("Using latest 5 years period. StartDate and FinishDate parameters are ignored.");
        GivenFinishDate = iTime(symbol, timeframe, 1); // Skipping 0 because it is not finished yet.
        GivenStartDate = GivenFinishDate - 5 * 365 * 24 * 3600; // 5 years ago.
    }

    if (Calculated_Time_Shift == 0)
    {
        if (PeriodToProcess == Last_N_Candles)
        {
            if (iBars(symbol, timeframe) < N + 2)
            {
                Print("Not enough candles: ", iBars(symbol, timeframe), " < ", N + 2);
                return false;
            }
            if (!print_off) Print("Using latest " + IntegerToString(N) + " candles period. StartDate and FinishDate parameters are ignored.");
            GivenFinishDate = iTime(symbol, timeframe, 1); // Skipping 0 because it is not finished yet.
            GivenStartDate = iTime(symbol, timeframe, 1 + N); // 5 years ago.
        }
    }
    else
    {
        if (!print_off) Print("Time shift is given. No MA-based statistics will be available.");
        GivenFinishDate -= Calculated_Time_Shift * 3600;
        GivenStartDate -= Calculated_Time_Shift * 3600;
    }

    int total = 0;
    if (Calculated_Time_Shift == 0)
    {
        ArraySetAsSeries(close_array, true);
        ArraySetAsSeries(open_array, true);
        ArraySetAsSeries(high_array, true);
        ArraySetAsSeries(low_array, true);
        ArraySetAsSeries(time_array, true);

        while (1)
        {
            int open_copied = CopyOpen(symbol, timeframe, GivenStartDate, GivenFinishDate, open_array);
            if (!print_off) Print("Found data points for Open: ", open_copied);
            int close_copied = CopyClose(symbol, timeframe, GivenStartDate, GivenFinishDate, close_array);
            if (!print_off) Print("Found data points for Close: ", close_copied);
            int high_copied = CopyHigh(symbol, timeframe, GivenStartDate, GivenFinishDate, high_array);
            if (!print_off) Print("Found data points for High: ", high_copied);
            int low_copied = CopyLow(symbol, timeframe, GivenStartDate, GivenFinishDate, low_array);
            if (!print_off) Print("Found data points for Low: ", low_copied);
            int time_copied = CopyTime(symbol, timeframe, GivenStartDate, GivenFinishDate, time_array);
            if (!print_off) Print("Found data points for Time: ", time_copied);

            if ((open_copied != close_copied) || (open_copied != high_copied) || (open_copied != low_copied) || (open_copied != time_copied))
            {
                Print("Inconsistent data.");
                return false;
            }

            if (open_copied == -1)
            {
                Print("Data not ready. Waiting for 1 second...");
                Sleep(1000);
            }
            else
            {
                total = open_copied - 1;

                if (open_copied < 2)
                {
                    Print("Not enough data for the period. Only ", open_copied, " bars found.");
                    return false;
                }

                break;
            }
        }
    }
    else
    {
        double OpenHourly[], CloseHourly[], HighHourly[], LowHourly[];
        datetime TimeHourly[];
        ArraySetAsSeries(OpenHourly, true);
        ArraySetAsSeries(CloseHourly, true);
        ArraySetAsSeries(HighHourly, true);
        ArraySetAsSeries(LowHourly, true);
        ArraySetAsSeries(TimeHourly, true);

        int time_copied = 0;
        while (1)
        {
            int open_copied = CopyOpen(symbol, PERIOD_H1, GivenStartDate, GivenFinishDate, OpenHourly);
            if (!print_off) Print("Found H1 data points for Open: ", open_copied);
            int close_copied = CopyClose(symbol, PERIOD_H1, GivenStartDate, GivenFinishDate, CloseHourly);
            if (!print_off) Print("Found H1 data points for Close: ", close_copied);
            int high_copied = CopyHigh(symbol, PERIOD_H1, GivenStartDate, GivenFinishDate, HighHourly);
            if (!print_off) Print("Found H1 data points for High: ", high_copied);
            int low_copied = CopyLow(symbol, PERIOD_H1, GivenStartDate, GivenFinishDate, LowHourly);
            if (!print_off) Print("Found H1 data points for Low: ", low_copied);
            time_copied = CopyTime(symbol, PERIOD_H1, GivenStartDate, GivenFinishDate, TimeHourly);
            if (!print_off) Print("Found H1 data points for Time: ", time_copied);

            if (open_copied == -1)
            {
                Print("Data not ready. Waiting for 1 second...");
                Sleep(1000);
            }
            else break;
        }

        int hours_in_period = PeriodSeconds(PERIOD_CURRENT) / 3600; // How many hours on the current period?
        datetime start_hour_time = 0;

        if (start_hour_time == 0) // Find period's starting point.
        {
            datetime time_adjusted = TimeHourly[time_copied - 1] + Calculated_Time_Shift * 3600;
            int h = TimeHour(time_adjusted);
            int d = TimeDayOfWeek(time_adjusted);
            int dm = TimeDay(time_adjusted);

            if (timeframe < PERIOD_D1) // H4 in MT4 and H6, H8, H12 in MT5.
            {
                start_hour_time = time_adjusted - (h % hours_in_period) * 3600;
            }
            else if (timeframe == PERIOD_D1)
            {
                start_hour_time = time_adjusted - h * 3600;
            }
            else if (timeframe == PERIOD_W1)
            {
                if (d == 0) d = 6; // Sunday = 6.
                else d--; // Monday = 0.
                start_hour_time = time_adjusted - d * 24 * 3600 -  h * 3600;
            }
            else if (timeframe == PERIOD_MN1)
            {
                dm--; // 1st = 0 hours.
                start_hour_time = time_adjusted - dm * 24 * 3600 -  h * 3600;
                hours_in_period = 28; // For max_size calculation.
            }
        }

        int max_size = ((int)TimeHourly[0] - (int)TimeHourly[time_copied - 1]) / hours_in_period + 1;
        ArrayResize(open_array, max_size);
        ArrayResize(high_array, max_size);
        ArrayResize(low_array, max_size);
        ArrayResize(close_array, max_size);
        ArrayResize(time_array, max_size);
        int j = 0;
        ArrayInitialize(time_array, 0);
        ArrayInitialize(open_array, 0);
        ArrayInitialize(high_array, -DBL_MAX);
        ArrayInitialize(low_array, DBL_MAX);
        for (int i = time_copied - 1; i >= 0; i--)
        {
            datetime time_adjusted = TimeHourly[i] + Calculated_Time_Shift * 3600;
            if (open_array[j] == 0) open_array[j] = OpenHourly[i];
            else if (time_adjusted >= time_array[j] + hours_in_period * 3600) // Carry over to the next current period candle.
            {
                close_array[j] = CloseHourly[i + 1]; // Close of the previous hour.
                start_hour_time += ((time_adjusted - time_array[j]) / (hours_in_period * 3600)) * (hours_in_period * 3600);
                j++;
                open_array[j] = OpenHourly[i];
            }
            if (high_array[j] < HighHourly[i]) high_array[j] = HighHourly[i];
            if (low_array[j] > LowHourly[i]) low_array[j] = LowHourly[i];
            if (timeframe == PERIOD_MN1)
            {
                int mon = TimeMonth(time_adjusted);
                hours_in_period = DaysInMonth[mon];
                if (mon == 2) hours_in_period += LeapYear(time_adjusted);
                hours_in_period = hours_in_period * 24;
            }
            time_array[j] = start_hour_time;
        }
        close_array[j] = CloseHourly[0];

        total = j + 1;

        if (!print_off) Print("Converted to ", total, " periods.");

        // Cut off unneeded data.
        ArrayResize(open_array, total);
        ArrayResize(high_array, total);
        ArrayResize(low_array, total);
        ArrayResize(close_array, total);
        ArrayResize(time_array, total);

        // Arrange arrays as timeseries for easier processing.
        ArraySetAsSeries(open_array, true);
        ArraySetAsSeries(high_array, true);
        ArraySetAsSeries(low_array, true);
        ArraySetAsSeries(close_array, true);
        ArraySetAsSeries(time_array, true);
    }

    double PC[], PR[], Spike[];
    int ABSMA[], ABEMA[], HHHLLLLH[], ConsBullBear[];
    int cnt_above_sma = 0, cnt_below_sma = 0, cnt_above_ema = 0, cnt_below_ema = 0, cnt_HHHL = 0, cnt_LLLH = 0, cnt_Bull = 0, cnt_Bear = 0;
    int j_s = 0, j_e = 0, j_hl = 0, j_bb = 0;
    // The oldest candle will be used in comparison to the next one only.
    int n = total - 1;
    ArrayResize(PC, n);
    ArrayResize(PR, n);
    ArrayResize(Spike, n);

    int diff = 0; // Will be needed for MA shift.

    if (Calculated_Time_Shift != 0)
        for (diff = 0; iTime(symbol, timeframe, diff) > time_array[0]; diff++) {;}

    int sma_handle = iMA(symbol, timeframe, MA_Period, 0, MODE_SMA, PRICE_CLOSE);
    int ema_handle = iMA(symbol, timeframe, MA_Period, 0, MODE_EMA, PRICE_CLOSE);
    double sma_array[];
    double ema_array[];
    CopyBuffer(sma_handle, 0, 0, iBars(symbol, timeframe), sma_array);
    CopyBuffer(ema_handle, 0, 0, iBars(symbol, timeframe), ema_array);
    ArraySetAsSeries(sma_array, true);
    ArraySetAsSeries(ema_array, true);

    for (int i = total - 2; i >= 0; i--)
    {
        double percentage_change = (MathAbs(close_array[i + 1] - close_array[i]) / close_array[i + 1]) * 100;
        PC[i] = percentage_change;
        double percentage_range = (MathAbs(high_array[i] - low_array[i]) / open_array[i]) * 100;
        PR[i] = percentage_range;
        
        double divisor = MathAbs(open_array[i] - close_array[i]);
        if (divisor == 0) divisor = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double spikiness = (high_array[i] - low_array[i]) / divisor;
        Spike[i] = spikiness;

        DoHHHLLLLHCounting(i, cnt_HHHL, cnt_LLLH, HHHLLLLH, j_hl);

        DoConsBullBearCounting(i, cnt_Bull, cnt_Bear, ConsBullBear, j_bb);

        // MA isn't available yet.
        if ((Calculated_Time_Shift != 0) || (i > iBars(symbol, timeframe) - MA_Period)) continue;

        double sma = sma_array[i + diff];
        DoMAComparison(i, sma, cnt_above_sma, cnt_below_sma, ABSMA, j_s);
        double ema = ema_array[i + diff];
        DoMAComparison(i, ema, cnt_above_ema, cnt_below_ema, ABEMA, j_e);
    }

    double mean, median;

    ArrayMeanMedian(PC, mean, median);
    PC_mean = mean;
    PC_median = median;
    if (!print_off)
    {
        Print("PC Median = ", DoubleToString(median, 2), "%");
        Print("PC Mean = ", DoubleToString(mean, 2), "%");
    }

    ArrayMeanMedian(PR, mean, median);
    PR_mean = mean;
    PR_median = median;
    if (!print_off)
    {
        Print("PR Median = ", DoubleToString(median, 2), "%");
        Print("PR Mean = ", DoubleToString(mean, 2), "%");
    }

    ArrayMeanMedian(Spike, mean, median);
    Spikiness_mean = mean;
    Spikiness_median = median;
    if (!print_off)
    {
        Print("Spikiness Median = ", DoubleToString(median, 2));
        Print("Spikiness Mean = ", DoubleToString(mean, 2));
    }

    if (Calculated_Time_Shift != 0)
    {
        ABSMA_mean = 0;
        ABSMA_median = 0;
        ABEMA_mean = 0;
        ABEMA_median = 0;
        if (!print_off)
        {
            Print("Median periods above/below SMA are not available because time shift is given.");
            Print("Mean periods above/below SMA are not available because time shift is given.");
            Print("Median periods above/below EMAare not available because time shift is given.");
            Print("Mean periods above/below EMAare not available because time shift is given.");
        }
    }
    else
    {
        ArrayResize(ABSMA, j_s);
        ArrayResize(ABEMA, j_e);

        ArrayMeanMedian(ABSMA, mean, median);
        ABSMA_mean = mean;
        ABSMA_median = median;
        if (!print_off)
        {
            Print("Median periods above/below SMA = ", DoubleToString(median, 1));
            Print("Mean periods above/below SMA = ", DoubleToString(mean, 1));
        }
        ArrayMeanMedian(ABEMA, mean, median);
        ABEMA_mean = mean;
        ABEMA_median = median;
        if (!print_off)
        {
            Print("Median periods above/below EMA = ", DoubleToString(median, 1));
            Print("Mean periods above/below EMA = ", DoubleToString(mean, 1));
        }
    }

    ArrayResize(HHHLLLLH, j_hl);
    if (ArraySize(HHHLLLLH) > 0)
    {
        ArrayMeanMedian(HHHLLLLH, mean, median);
    }
    else mean = 0;
    HHHLLLLH_mean = mean;
    if (!print_off) Print("Mean number of consecutive HHHL/LLLH = ", DoubleToString(mean, 3));

    ArrayResize(ConsBullBear, j_bb);
    if (ArraySize(ConsBullBear) > 0)
    {
        ArrayMeanMedian(ConsBullBear, mean, median);
    }
    else mean = 0;
    ConsBullBear_mean = mean;
    if (!print_off) Print("Mean number of consecutive bull/bear candles = ", DoubleToString(mean, 3));

    return true;
}


// Sorts array and records its mean and median values via the passed references.
template<typename T>
void ArrayMeanMedian(T &array[], double &mean, double &median)
{
    // Calculate median.
    median = 0;
    ArraySort(array);
    int n = ArraySize(array);
    int half_n;
    // Zero:
    if (n == 0) median = 0;
    // Even number:
    else if (n % 2 == 1)
    {
        half_n = n / 2;
        median = array[half_n];
    }
    // Odd number:
    else
    {
        half_n = n / 2 - 1;
        median = ((double)array[half_n] + (double)array[half_n + 1]) / 2;
    }

    // Calculate mean.
    mean = 0;
    for (int i = 0; i < n; i++) mean += array[i];
    if (n > 0) mean = mean / n;
}

// Compares current close to the MA value and tracks the number of consecutive closes above or below the MA.
void TrendStats::DoMAComparison(const int i, const double ma, int &cnt_above, int &cnt_below, int &array[], int &j)
{
    bool above, below;
    if (close_array[i] > ma)
    {
        above = true;
        below = false;
    }
    else if (close_array[i] < ma)
    {
        above = false;
        below = true;
    }
    else
    {
        above = false;
        below = false;
    }

    if (above) cnt_above++;
    
    if ((!above) || (i == 0)) // Terminated the sequence or end of test.
    {
        if (cnt_above > 0)
        {
            ArrayResize(array, j + 1, 100);
            array[j] = cnt_above;
            j++;
            cnt_above = 0;
        }
    }

    if (below) cnt_below++;
    
    if ((!below) || (i == 0)) // Terminated the sequence or end of test.
    {
        if (cnt_below > 0)
        {
            ArrayResize(array, j + 1, 100);
            array[j] = cnt_below;
            j++;
            cnt_below = 0;
        }
    }
}

// Keeps track of continous streaks of HHHL or LLLH.
void TrendStats::DoHHHLLLLHCounting(const int i, int &cnt_HHHL, int &cnt_LLLH, int &array[], int &j)
{
    bool HHHL, LLLH;
    if ((high_array[i] > high_array[i + 1]) && (low_array[i] > low_array[i + 1]))
    {
        HHHL = true;
        LLLH = false;
    }
    else if ((low_array[i] < low_array[i + 1]) && (high_array[i] < high_array[i + 1]))
    {
        HHHL = false;
        LLLH = true;
    }
    else
    {
        HHHL = false;
        LLLH = false;
    }

    if (HHHL) cnt_HHHL++;
    
    if ((!HHHL) || (i == 0)) // Terminated the sequence or end of test.
    {
        if (cnt_HHHL > 0)
        {
            ArrayResize(array, j + 1, 100);
            array[j] = cnt_HHHL;
            j++;
            cnt_HHHL = 0;
        }
    }

    if (LLLH) cnt_LLLH++;
    
    if ((!LLLH) || (i == 0)) // Terminated the sequence or end of test.
    {
        if (cnt_LLLH > 0)
        {
            ArrayResize(array, j + 1, 100);
            array[j] = cnt_LLLH;
            j++;
            cnt_LLLH = 0;
        }
    }
}

// Keeps track of continous streaks of bullish and bearish candles.
void TrendStats::DoConsBullBearCounting(const int i, int &cnt_Bull, int &cnt_Bear, int &array[], int &j)
{
    bool bull, bear;
    if (close_array[i] > open_array[i])
    {
        bull = true;
        bear = false;
    }
    else if (close_array[i] < open_array[i])
    {
        bull = false;
        bear = true;
    }
    else
    {
        bull = false;
        bear = false;
    }

    if (bull) cnt_Bull++;
    
    if ((!bull) || (i == 0)) // Terminated the sequence or end of test.
    {
        if (cnt_Bull > 0)
        {
            ArrayResize(array, j + 1, 100);
            array[j] = cnt_Bull;
            j++;
            cnt_Bull = 0;
        }
    }

    if (bear) cnt_Bear++;
    
    if ((!bear) || (i == 0)) // Terminated the sequence or end of test.
    {
        if (cnt_Bear > 0)
        {
            ArrayResize(array, j + 1, 100);
            array[j] = cnt_Bear;
            j++;
            cnt_Bear = 0;
        }
    }
}

int TimeHour(const datetime date)
{
    MqlDateTime dt;
    TimeToStruct(date, dt);
    return dt.hour;
}

int TimeDayOfWeek(const datetime date)
{
    MqlDateTime dt;
    TimeToStruct(date, dt);
    return dt.day_of_week;
}

int TimeDay(const datetime date)
{
    MqlDateTime dt;
    TimeToStruct(date, dt);
    return dt.day;
}

int TimeMonth(const datetime date)
{
    MqlDateTime dt;
    TimeToStruct(date, dt);
    return dt.mon;
}

int TimeYear(const datetime date)
{
    MqlDateTime dt;
    TimeToStruct(date, dt);
    return dt.year;
}

// https://stackoverflow.com/questions/42848166/how-to-find-the-number-of-days-in-the-current-month-using-mql4
int DaysInMonth[] =
{
    0,    // 0th month
    31,   // Jan
    28,   // Feb + int LeapYear(const datetime date)
    31,   // Mar
    30,   // Aug
    31,   // May
    30,   // Jun
    31,   // Jul
    31,   // Aug
    30,   // Sep
    31,   // Oct
    30,   // Nov
    31    // Dec
};

int LeapYear(const datetime date)
{
    int y = TimeYear(date);
    if ((y % 4 == 0) && ((y % 100 != 0) || (y % 400 == 0))) return 1;
    return 0;
}
//+------------------------------------------------------------------+