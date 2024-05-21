//+------------------------------------------------------------------+
//|                                                   TrendStats.mq4 |
//|                             Copyright © 2019-2024, EarnForex.com |
//|                                       https://www.earnforex.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019-2024, EarnForex.com"
#property link      "https://www.earnforex.com/guides/which-forex-pair-trends-the-most/"
#property version   "1.01"
#property show_inputs
#property strict

#property description "Calculates trend statistics for the currency pair on the current timeframe."
#property description "Uses a date range. Outputs the values to the chart."
#property description "Available stats:"
#property description " - Average percentage true range"
#property description " - Average percentage volatility"
#property description " - Average consecutive closes above/below MA"
#property description " - Average consecutive HHHL/LLLH"
#property description " - Average consecutive bullish/bearish candles"
#property description " - Average spikiness"
#property description "Results are saved to files (written as .csv to \\MQL4\\Files\\)."

#include "TrendStats.mqh";

input string   Symbols =         "EURUSD, USDJPY, GBPUSD, AUDUSD, USDCAD, USDCHF, NZDUSD, EURJPY, EURGBP, GBPJPY";
input string   Timeframes =      "D1, W1, MN";
input period   PeriodToProcess = Last_5_Years;
input string   dummy1 =          "Set the above to Time_Period, then set the period below if you need to use specific period:";
input datetime StartDate =       __DATE__;
input datetime FinishDate =      __DATE__;
input string   dummy2 =          "If Last_N_Candles is used, set the N below:";
input int      N =               200;
input int      Time_Shift =      0; // Time shift for day start (-12 to +12 hours)
input int      MA_Period =       50; // MA Period for trendedness based on MA
input string   FileNamePrefix =  "TrendStats";
input bool     SilentMode =      false;

// Output data
double PC_mean[], PC_median[], PR_mean[], PR_median[], ABSMA_mean[], ABSMA_median[], ABEMA_mean[], ABEMA_median[], HHHLLLLH_mean[], ConsBullBear_mean[], Spikiness_mean[], Spikiness_median[];

// Output arrays and counts.
string symbols_array[];
int symbols_count;
string timeframes_array[];
int timeframes_count;

void OnStart()
{
    datetime GivenStartDate = StartDate;
    datetime GivenFinishDate = FinishDate;
    int Calculated_Time_Shift;

    if (((Time_Shift > 12) || (Time_Shift < -12)) && (PeriodToProcess != Last_N_Candles))
    {
        Alert("Time shift should be between -12 and 12.");
        return;
    }

    if ((PeriodToProcess == Last_N_Candles) && (Time_Shift != 0))
    {
        Print("Time Shift is ignored if Last_N_Candles is used as a period.");
        Calculated_Time_Shift = 0;
    }
    else Calculated_Time_Shift = Time_Shift;

    symbols_count = ProcessInput(Symbols, symbols_array);
    if (symbols_count == 0)
    {
        Print("No symbols found in the input string.");
        return;
    }

    timeframes_count = ProcessInput(Timeframes, timeframes_array);
    if (timeframes_count == 0)
    {
        Print("No timeframes found in the input string.");
        return;
    }

    ArrayResize(PC_mean, symbols_count * timeframes_count);
    ArrayResize(PC_median, symbols_count * timeframes_count);
    ArrayResize(PR_mean, symbols_count * timeframes_count);
    ArrayResize(PR_median, symbols_count * timeframes_count);
    ArrayResize(ABSMA_mean, symbols_count * timeframes_count);
    ArrayResize(ABSMA_median, symbols_count * timeframes_count);
    ArrayResize(ABEMA_mean, symbols_count * timeframes_count);
    ArrayResize(ABEMA_median, symbols_count * timeframes_count);
    ArrayResize(HHHLLLLH_mean, symbols_count * timeframes_count);
    ArrayResize(ConsBullBear_mean, symbols_count * timeframes_count);
    ArrayResize(Spikiness_mean, symbols_count * timeframes_count);
    ArrayResize(Spikiness_median, symbols_count * timeframes_count);

    ArrayInitialize(PC_mean, 0);
    ArrayInitialize(PC_median, 0);
    ArrayInitialize(PR_mean, 0);
    ArrayInitialize(PR_median, 0);
    ArrayInitialize(ABSMA_mean, 0);
    ArrayInitialize(ABSMA_median, 0);
    ArrayInitialize(ABEMA_mean, 0);
    ArrayInitialize(ABEMA_median, 0);
    ArrayInitialize(HHHLLLLH_mean, 0);
    ArrayInitialize(ConsBullBear_mean, 0);
    ArrayInitialize(Spikiness_mean, 0);
    ArrayInitialize(Spikiness_median, 0);

    // Processing all timeframes for each symbol.
    for (int i = 0; i < symbols_count; i++)
    {
        for (int j = 0; j < timeframes_count; j++)
        {
            Print("Starting to work on ", symbols_array[i], " @ ", timeframes_array[j], "...");

            TrendStats *TS;
            TS = new TrendStats;

            if (!TS.Initialize(symbols_array[i], timeframes_array[j], GivenStartDate, GivenFinishDate, PeriodToProcess, N, Calculated_Time_Shift, MA_Period))
            {
                Print("Failed to initialize ", symbols_array[i], " @ ", timeframes_array[j], ". Wrong timeframe?");
                continue;
            }

            if (!TS.PrepareData())
            {
                Print("Failed to prepare data for ", symbols_array[i], " @ ", timeframes_array[j], ".");
                delete TS;
                continue;
            }

            PC_mean[i * timeframes_count + j] = TS.PC_mean;
            PC_median[i * timeframes_count + j] = TS.PC_median;
            PR_mean[i * timeframes_count + j] = TS.PR_mean;
            PR_median[i * timeframes_count + j] = TS.PR_median;
            ABSMA_mean[i * timeframes_count + j] = TS.ABSMA_mean;
            ABSMA_median[i * timeframes_count + j] = TS.ABSMA_median;
            ABEMA_mean[i * timeframes_count + j] = TS.ABEMA_mean;
            ABEMA_median[i * timeframes_count + j] = TS.ABEMA_median;
            HHHLLLLH_mean[i * timeframes_count + j] = TS.HHHLLLLH_mean;
            ConsBullBear_mean[i * timeframes_count + j] = TS.ConsBullBear_mean;

            delete TS;

            Print("Finished working on ", symbols_array[i], " @ ", timeframes_array[j], ".");
        }
    }

    if (FileNamePrefix != "") RecordDataToFiles();
}

// Fills array out of string separated by ","/";"/" ", trims spaces, returns count.
int ProcessInput(const string inp, string &array[])
{
    int counter = 0;
    string s = inp;

    if (inp == "") return 0;

    StringReplace(s, " ", ";");
    StringReplace(s, ",", ";");
    // Split string using ';' as a separator, getting an array with clean strings.
    string result[];

    // Maximum possible number of elements.
    int n = StringSplit(s, ';', result);
    ArrayResize(array, n);
    for (int i = 0; i < n; i++)
    {
        result[i] = StringTrimRight(StringTrimLeft(result[i]));
        if (result[i] == "") continue;
        array[counter] = result[i];
        counter++;
    }
    ArrayResize(array, counter);
    return counter;
}

bool RecordDataToFiles()
{
    string FileName, s;
    int fh;

    // Percentage change - mean and median.
    FileName = FileNamePrefix + "PC.csv";
    fh = FileOpen(FileName, FILE_CSV | FILE_WRITE);
    if (fh == INVALID_HANDLE)
    {
        Print("Failed to open file for writing: " + FileName + ". Error: " + IntegerToString(GetLastError()));
        return false;
    }

    s = "Currency pair";
    for (int j = 0; j < timeframes_count; j++)
    {
        s += ";" + timeframes_array[j] + " Mean;" + timeframes_array[j] + " Median";
    }
    FileWrite(fh, s);
    for (int i = 0; i < symbols_count; i++)
    {
        s = symbols_array[i];
        for (int j = 0; j < timeframes_count; j++)
        {
            s += ";" + DoubleToString(PC_mean[i * timeframes_count + j], 2) + ";" + DoubleToString(PC_median[i * timeframes_count + j], 2);
        }
        FileWrite(fh, s);
    }

    FileClose(fh);
    Print("File ", FileName, " written.");

    // Percentage range - mean and median.
    FileName = FileNamePrefix + "PR.csv";
    fh = FileOpen(FileName, FILE_CSV | FILE_WRITE);
    if (fh == INVALID_HANDLE)
    {
        Print("Failed to open file for writing: " + FileName + ". Error: " + IntegerToString(GetLastError()));
        return false;
    }

    s = "Currency pair";
    for (int j = 0; j < timeframes_count; j++)
    {
        s += ";" + timeframes_array[j] + " Mean;" + timeframes_array[j] + " Median";
    }
    FileWrite(fh, s);
    for (int i = 0; i < symbols_count; i++)
    {
        s = symbols_array[i];
        for (int j = 0; j < timeframes_count; j++)
        {
            s += ";" + DoubleToString(PR_mean[i * timeframes_count + j], 2) + ";" + DoubleToString(PR_median[i * timeframes_count + j], 2);
        }
        FileWrite(fh, s);
    }

    FileClose(fh);
    Print("File ", FileName, " written.");

    // Above/below SMA/EMA - mean and median.
    for (int j = 0; j < timeframes_count; j++)
    {
        FileName = FileNamePrefix + timeframes_array[j] + "ABMA.csv";
        fh = FileOpen(FileName, FILE_CSV | FILE_WRITE);
        if (fh == INVALID_HANDLE)
        {
            Print("Failed to open file for writing: " + FileName + ". Error: " + IntegerToString(GetLastError()));
            return false;
        }

        s = "Currency pair;SMA Mean;SMA Median;EMA Mean;EMA Median";
        FileWrite(fh, s);
        for (int i = 0; i < symbols_count; i++)
        {
            s = symbols_array[i];
            s += ";" + DoubleToString(ABSMA_mean[i * timeframes_count + j], 1) + ";" + DoubleToString(ABSMA_median[i * timeframes_count + j], 1) + ";" + DoubleToString(ABEMA_mean[i * timeframes_count + j], 1) + ";" + DoubleToString(ABEMA_median[i * timeframes_count + j], 1);
            FileWrite(fh, s);
        }

        FileClose(fh);
        Print("File ", FileName, " written.");
    }

    // Consectuive HHHL/LLLH - mean.
    FileName = FileNamePrefix + "HHHLLLLH.csv";
    fh = FileOpen(FileName, FILE_CSV | FILE_WRITE);
    if (fh == INVALID_HANDLE)
    {
        Print("Failed to open file for writing: " + FileName + ". Error: " + IntegerToString(GetLastError()));
        return false;
    }

    s = "Currency pair";
    for (int j = 0; j < timeframes_count; j++)
    {
        s += ";" + timeframes_array[j];
    }
    FileWrite(fh, s);
    for (int i = 0; i < symbols_count; i++)
    {
        s = symbols_array[i];
        for (int j = 0; j < timeframes_count; j++)
        {
            s += ";" + DoubleToString(HHHLLLLH_mean[i * timeframes_count + j], 3);
        }
        FileWrite(fh, s);
    }

    FileClose(fh);
    Print("File ", FileName, " written.");

    // Consectuive bullish/bearish candles - mean.
    FileName = FileNamePrefix + "ConsBullBear.csv";
    fh = FileOpen(FileName, FILE_CSV | FILE_WRITE);
    if (fh == INVALID_HANDLE)
    {
        Print("Failed to open file for writing: " + FileName + ". Error: " + IntegerToString(GetLastError()));
        return false;
    }

    s = "Currency pair";
    for (int j = 0; j < timeframes_count; j++)
    {
        s += ";" + timeframes_array[j];
    }
    FileWrite(fh, s);
    for (int i = 0; i < symbols_count; i++)
    {
        s = symbols_array[i];
        for (int j = 0; j < timeframes_count; j++)
        {
            s += ";" + DoubleToString(ConsBullBear_mean[i * timeframes_count + j], 3);
        }
        FileWrite(fh, s);
    }

    FileClose(fh);
    Print("File ", FileName, " written.");

    // Spikiness - mean and median.
    FileName = FileNamePrefix + "Spikiness.csv";
    fh = FileOpen(FileName, FILE_CSV | FILE_WRITE);
    if (fh == INVALID_HANDLE)
    {
        Print("Failed to open file for writing: " + FileName + ". Error: " + IntegerToString(GetLastError()));
        return false;
    }

    s = "Currency pair";
    for (int j = 0; j < timeframes_count; j++)
    {
        s += ";" + timeframes_array[j] + " Mean;" + timeframes_array[j] + " Median";
    }
    FileWrite(fh, s);
    for (int i = 0; i < symbols_count; i++)
    {
        s = symbols_array[i];
        for (int j = 0; j < timeframes_count; j++)
        {
            s += ";" + DoubleToString(Spikiness_mean[i * timeframes_count + j], 2) + ";" + DoubleToString(Spikiness_median[i * timeframes_count + j], 2);
        }
        FileWrite(fh, s);
    }

    FileClose(fh);
    Print("File ", FileName, " written.");

    return true;
}
//+------------------------------------------------------------------+