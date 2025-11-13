//+------------------------------------------------------------------+
//|                                          EngulfingPatternEA.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- Input parameters
input double   LotSize = 0.1;                    // Lot size for trading
input int      StopLoss = 100;                   // Stop Loss in points
input int      TakeProfit = 200;                 // Take Profit in points
input bool     UseBullishEngulfing = true;       // Trade bullish engulfing patterns
input bool     UseBearishEngulfing = true;       // Trade bearish engulfing patterns
input int      MagicNumber = 123456;             // Magic number for identification
input string   TradeComment = "Engulfing EA";    // Trade comment
input bool     OneTradePerSignal = true;         // Only one trade per signal
input int      MinCandleSize = 10;               // Minimum candle size in points
input bool     UseTrailingStop = false;          // Use trailing stop
input int      TrailingStop = 50;                // Trailing stop in points
input int      TrailingStep = 10;                // Trailing step in points

//--- Global variables
CTrade trade;
datetime lastBarTime = 0;
bool tradeTakenThisBar = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set magic number
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);

   Print("Engulfing Pattern EA initialized successfully");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString((ENUM_TIMEFRAMES)_Period));
   Print("Lot Size: ", LotSize);
   Print("Stop Loss: ", StopLoss, " points");
   Print("Take Profit: ", TakeProfit, " points");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Engulfing Pattern EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      tradeTakenThisBar = false;

      //--- Check for engulfing patterns on the completed bar
      CheckEngulfingPattern();
   }

   //--- Apply trailing stop if enabled
   if(UseTrailingStop)
   {
      ApplyTrailingStop();
   }
}

//+------------------------------------------------------------------+
//| Check for engulfing candlestick patterns                        |
//+------------------------------------------------------------------+
void CheckEngulfingPattern()
{
   //--- Skip if we already took a trade this bar
   if(OneTradePerSignal && tradeTakenThisBar)
      return;

   //--- Get candle data for previous two bars (bar 1 and bar 2)
   double open1 = iOpen(_Symbol, _Period, 1);
   double close1 = iClose(_Symbol, _Period, 1);
   double high1 = iHigh(_Symbol, _Period, 1);
   double low1 = iLow(_Symbol, _Period, 1);

   double open2 = iOpen(_Symbol, _Period, 2);
   double close2 = iClose(_Symbol, _Period, 2);
   double high2 = iHigh(_Symbol, _Period, 2);
   double low2 = iLow(_Symbol, _Period, 2);

   //--- Calculate candle sizes in points
   double candle1Size = MathAbs(close1 - open1) / _Point;
   double candle2Size = MathAbs(close2 - open2) / _Point;

   //--- Check minimum candle size requirement
   if(candle1Size < MinCandleSize || candle2Size < MinCandleSize)
      return;

   //--- Check for Bullish Engulfing Pattern
   // Condition: Previous candle is bearish (red), current candle is bullish (green)
   // and current candle body completely engulfs previous candle body
   if(UseBullishEngulfing)
   {
      bool isBullishEngulfing = (close2 < open2) &&           // Previous candle is bearish
                                 (close1 > open1) &&           // Current candle is bullish
                                 (open1 < close2) &&           // Current open below previous close
                                 (close1 > open2);             // Current close above previous open

      if(isBullishEngulfing)
      {
         Print("Bullish Engulfing Pattern detected at bar 1");
         OpenBuyTrade();
         tradeTakenThisBar = true;
         return;
      }
   }

   //--- Check for Bearish Engulfing Pattern
   // Condition: Previous candle is bullish (green), current candle is bearish (red)
   // and current candle body completely engulfs previous candle body
   if(UseBearishEngulfing)
   {
      bool isBearishEngulfing = (close2 > open2) &&           // Previous candle is bullish
                                 (close1 < open1) &&           // Current candle is bearish
                                 (open1 > close2) &&           // Current open above previous close
                                 (close1 < open2);             // Current close below previous open

      if(isBearishEngulfing)
      {
         Print("Bearish Engulfing Pattern detected at bar 1");
         OpenSellTrade();
         tradeTakenThisBar = true;
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Open a buy trade                                                 |
//+------------------------------------------------------------------+
void OpenBuyTrade()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = 0, tp = 0;

   //--- Calculate Stop Loss and Take Profit
   if(StopLoss > 0)
      sl = ask - StopLoss * _Point;

   if(TakeProfit > 0)
      tp = ask + TakeProfit * _Point;

   //--- Normalize prices
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   //--- Open buy position
   if(trade.Buy(LotSize, _Symbol, ask, sl, tp, TradeComment))
   {
      Print("BUY order opened successfully. Ticket: ", trade.ResultOrder());
      Print("Entry: ", ask, " | SL: ", sl, " | TP: ", tp);
   }
   else
   {
      Print("Error opening BUY order: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Open a sell trade                                                |
//+------------------------------------------------------------------+
void OpenSellTrade()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = 0, tp = 0;

   //--- Calculate Stop Loss and Take Profit
   if(StopLoss > 0)
      sl = bid + StopLoss * _Point;

   if(TakeProfit > 0)
      tp = bid - TakeProfit * _Point;

   //--- Normalize prices
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   //--- Open sell position
   if(trade.Sell(LotSize, _Symbol, bid, sl, tp, TradeComment))
   {
      Print("SELL order opened successfully. Ticket: ", trade.ResultOrder());
      Print("Entry: ", bid, " | SL: ", sl, " | TP: ", tp);
   }
   else
   {
      Print("Error opening SELL order: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Apply trailing stop to open positions                            |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      long posType = PositionGetInteger(POSITION_TYPE);
      double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL = PositionGetDouble(POSITION_SL);
      double posTP = PositionGetDouble(POSITION_TP);

      double currentPrice = (posType == POSITION_TYPE_BUY) ?
                           SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      //--- For Buy positions
      if(posType == POSITION_TYPE_BUY)
      {
         double newSL = currentPrice - TrailingStop * _Point;
         newSL = NormalizeDouble(newSL, _Digits);

         if(currentPrice > posOpenPrice + TrailingStop * _Point)
         {
            if(posSL < newSL - TrailingStep * _Point || posSL == 0)
            {
               if(trade.PositionModify(ticket, newSL, posTP))
               {
                  Print("Trailing stop updated for BUY position #", ticket, " New SL: ", newSL);
               }
            }
         }
      }

      //--- For Sell positions
      if(posType == POSITION_TYPE_SELL)
      {
         double newSL = currentPrice + TrailingStop * _Point;
         newSL = NormalizeDouble(newSL, _Digits);

         if(currentPrice < posOpenPrice - TrailingStop * _Point)
         {
            if(posSL > newSL + TrailingStep * _Point || posSL == 0)
            {
               if(trade.PositionModify(ticket, newSL, posTP))
               {
                  Print("Trailing stop updated for SELL position #", ticket, " New SL: ", newSL);
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
