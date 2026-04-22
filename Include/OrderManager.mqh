//+------------------------------------------------------------------+
//|                                                OrderManager.mqh  |
//|                                  Lógica de Gestión de Órdenes     |
//+------------------------------------------------------------------+
#property strict

// Parámetros de configuración (pueden ser ajustados desde el EA principal)
int OM_ButtonWidth = 120;
int OM_ButtonHeight = 25;
int OM_PanelMarginLeft = 10;
color OM_ButtonTextColor = clrWhite;
color OM_PanelBgColor = clrBlack;

// Variables globales de nombres de objetos
string OM_btnToggleName = "OM_btnTogglePanel";
string OM_panelBgName = "OM_objPanelBackground";
string OM_btnCloseAll = "OM_btnCloseAll";
string OM_btnCloseProfits = "OM_btnCloseProfits";
string OM_btnSetTP = "OM_btnSetTP";
string OM_btnSetSL = "OM_btnSetSL";

// Variables para diálogos
string OM_editTPName = "OM_editTPInput", OM_editSLName = "OM_editSLInput";
string OM_btnTPConfirm = "OM_btnTPConfirm", OM_btnTPCancel = "OM_btnTPCancel";
string OM_btnSLConfirm = "OM_btnSLConfirm", OM_btnSLCancel = "OM_btnSLCancel";
string OM_lblTPTitle = "OM_lblTPTitle", OM_lblSLTitle = "OM_lblSLTitle";

bool OM_panelVisible = false;
bool OM_showingTPDialog = false;
bool OM_showingSLDialog = false;

int SLIPERAGE_PIPS = 2; // pips de sliperage al cerrar ordenes

//+------------------------------------------------------------------+
//| Inicialización                                                    |
//+------------------------------------------------------------------+
void OM_OnInit()
{
   OM_DeleteAllObjects();
   OM_UpdateUI();
}

//+------------------------------------------------------------------+
//| Desinicialización                                                 |
//+------------------------------------------------------------------+
void OM_OnDeinit()
{
   OM_DeleteAllObjects();
}

//+------------------------------------------------------------------+
//| Eventos del Gráfico                                               |
//+------------------------------------------------------------------+
void OM_OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if (id == CHARTEVENT_OBJECT_CLICK)
   {
      // BOTÓN DESPLEGABLE
      if (sparam == OM_btnToggleName)
      {
         OM_panelVisible = !OM_panelVisible;
         OM_UpdateUI();
         ObjectSetInteger(0, OM_btnToggleName, OBJPROP_STATE, false);
         ChartRedraw();
         return;
      }
      // BOTONES DEL PANEL
      if (OM_panelVisible)
      {
         if (sparam == OM_btnCloseAll)
         {
            OM_CloseAllOrders();
            ObjectSetInteger(0, OM_btnCloseAll, OBJPROP_STATE, false);
         }
         else if (sparam == OM_btnCloseProfits)
         {
            OM_CloseProfitableOrders();
            ObjectSetInteger(0, OM_btnCloseProfits, OBJPROP_STATE, false);
         }
         else if (sparam == OM_btnSetTP)
         {
            OM_ShowTPDialog();
            ObjectSetInteger(0, OM_btnSetTP, OBJPROP_STATE, false);
         }
         else if (sparam == OM_btnSetSL)
         {
            OM_ShowSLDialog();
            ObjectSetInteger(0, OM_btnSetSL, OBJPROP_STATE, false);
         }
      }
      // BOTONES DEL DIÁLOGO -CONFIRMAR/CANCELAR-
      if (sparam == OM_btnTPConfirm)
      {
         OM_ProcessTPInput();
         ObjectSetInteger(0, OM_btnTPConfirm, OBJPROP_STATE, false);
      }
      else if (sparam == OM_btnTPCancel)
      {
         OM_HideTPDialog();
         ObjectSetInteger(0, OM_btnTPCancel, OBJPROP_STATE, false);
      }
      else if (sparam == OM_btnSLConfirm)
      {
         OM_ProcessSLInput();
         ObjectSetInteger(0, OM_btnSLConfirm, OBJPROP_STATE, false);
      }
      else if (sparam == OM_btnSLCancel)
      {
         OM_HideSLDialog();
         ObjectSetInteger(0, OM_btnSLCancel, OBJPROP_STATE, false);
      }

      ChartRedraw();
   }

   // DIÁLOGO DE EDICIÓN -AL INDICAR EL VALOR DEL TAKE PROFIT/STOP LOSS
   if (id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if (sparam == OM_editTPName && OM_showingTPDialog)
         OM_ProcessTPInput();
      else if (sparam == OM_editSLName && OM_showingSLDialog)
         OM_ProcessSLInput();
   }
}

//+------------------------------------------------------------------+
//| Actualizar UI                                                     |
//+------------------------------------------------------------------+
void OM_UpdateUI()
{
   ObjectDelete(0, OM_panelBgName);
   ObjectDelete(0, OM_btnCloseAll);
   ObjectDelete(0, OM_btnCloseProfits);
   ObjectDelete(0, OM_btnSetTP);
   ObjectDelete(0, OM_btnSetSL);

   if (OM_panelVisible)
   {
      int panelH = (OM_ButtonHeight + 5) * 4 + 45;
      ObjectCreate(0, OM_panelBgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, OM_panelBgName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, OM_panelBgName, OBJPROP_XDISTANCE, OM_PanelMarginLeft);
      ObjectSetInteger(0, OM_panelBgName, OBJPROP_YDISTANCE, 25);
      ObjectSetInteger(0, OM_panelBgName, OBJPROP_XSIZE, OM_ButtonWidth + 20);
      ObjectSetInteger(0, OM_panelBgName, OBJPROP_YSIZE, panelH);
      ObjectSetInteger(0, OM_panelBgName, OBJPROP_BGCOLOR, OM_PanelBgColor);
      ObjectSetInteger(0, OM_panelBgName, OBJPROP_COLOR, clrDimGray);
      ObjectSetInteger(0, OM_panelBgName, OBJPROP_BACK, false);
   }

   ObjectDelete(0, OM_btnToggleName);
   ObjectCreate(0, OM_btnToggleName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, OM_btnToggleName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, OM_btnToggleName, OBJPROP_XDISTANCE, OM_PanelMarginLeft + 5);
   ObjectSetInteger(0, OM_btnToggleName, OBJPROP_YDISTANCE, 25);
   ObjectSetInteger(0, OM_btnToggleName, OBJPROP_XSIZE, OM_ButtonWidth);
   ObjectSetInteger(0, OM_btnToggleName, OBJPROP_YSIZE, 20);
   ObjectSetInteger(0, OM_btnToggleName, OBJPROP_BGCOLOR, clrGray);
   ObjectSetInteger(0, OM_btnToggleName, OBJPROP_COLOR, OM_ButtonTextColor);
   ObjectSetInteger(0, OM_btnToggleName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, OM_btnToggleName, OBJPROP_TEXT, (OM_panelVisible ? "Order Manager ▲" : "Order Manager ▼"));
   ObjectSetInteger(0, OM_btnToggleName, OBJPROP_STATE, false);

   if (OM_panelVisible)
   {
      int x = OM_PanelMarginLeft + 10;
      int y = 10 + 20 + 25;
      OM_CreateBtn(OM_btnSetSL, "Set SL Global", x, y, OM_ButtonWidth, OM_ButtonHeight, clrOrangeRed);
      y += OM_ButtonHeight + 5;
      OM_CreateBtn(OM_btnSetTP, "Set TP Global", x, y, OM_ButtonWidth, OM_ButtonHeight, clrDodgerBlue);
      y += OM_ButtonHeight + 5;
      OM_CreateBtn(OM_btnCloseProfits, "Close Profits", x, y, OM_ButtonWidth, OM_ButtonHeight, clrForestGreen);
      y += OM_ButtonHeight + 5;
      OM_CreateBtn(OM_btnCloseAll, "Close all", x, y, OM_ButtonWidth, OM_ButtonHeight, clrCrimson);
   }
   ChartRedraw();
}

void OM_CreateBtn(string name, string text, int x, int y, int w, int h, color bg)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, OM_ButtonTextColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| DIÁLOGOS                                                          |
//+------------------------------------------------------------------+
void OM_ShowTPDialog()
{
   if (OM_showingTPDialog)
      return;
   int w = 250, h = 130;
   int cx = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) / 2 - w / 2;
   int cy = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS) / 2 - h / 2;
   // Create dialog panel
   ObjectCreate(0, "OM_dlgTPBg", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "OM_dlgTPBg", OBJPROP_XDISTANCE, cx);
   ObjectSetInteger(0, "OM_dlgTPBg", OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, "OM_dlgTPBg", OBJPROP_XSIZE, w);
   ObjectSetInteger(0, "OM_dlgTPBg", OBJPROP_YSIZE, h);
   ObjectSetInteger(0, "OM_dlgTPBg", OBJPROP_BGCOLOR, clrWhiteSmoke);
   // Create dialog labels
   ObjectCreate(0, OM_lblTPTitle, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OM_lblTPTitle, OBJPROP_XDISTANCE, cx + 10);
   ObjectSetInteger(0, OM_lblTPTitle, OBJPROP_YDISTANCE, cy + 10);
   ObjectSetString(0, OM_lblTPTitle, OBJPROP_TEXT, "Take Profit (Precio):");
   ObjectSetInteger(0, OM_lblTPTitle, OBJPROP_COLOR, clrBlack);
   // Create dialog inputs
   ObjectCreate(0, OM_editTPName, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, OM_editTPName, OBJPROP_XDISTANCE, cx + 10);
   ObjectSetInteger(0, OM_editTPName, OBJPROP_YDISTANCE, cy + 35);
   ObjectSetInteger(0, OM_editTPName, OBJPROP_XSIZE, w - 20);
   ObjectSetInteger(0, OM_editTPName, OBJPROP_YSIZE, 30);
   ObjectSetString(0, OM_editTPName, OBJPROP_TEXT, DoubleToString(Ask, Digits));
   ObjectSetInteger(0, OM_editTPName, OBJPROP_ALIGN, ALIGN_CENTER);
   OM_CreateDlgBtn(OM_btnTPConfirm, "Confirmar", cx + 10, cy + 75, 110, 30, clrGreen);
   OM_CreateDlgBtn(OM_btnTPCancel, "Cancelar", cx + 130, cy + 75, 110, 30, clrGray);
   OM_showingTPDialog = true;
}

void OM_HideTPDialog()
{
   ObjectDelete(0, "OM_dlgTPBg");
   ObjectDelete(0, OM_lblTPTitle);
   ObjectDelete(0, OM_editTPName);
   ObjectDelete(0, OM_btnTPConfirm);
   ObjectDelete(0, OM_btnTPCancel);
   OM_showingTPDialog = false;
}

void OM_ShowSLDialog()
{
   if (OM_showingSLDialog)
      return;
   int w = 250, h = 130;
   int cx = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) / 2 - w / 2;
   int cy = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS) / 2 - h / 2;
   // Create dialog panel
   ObjectCreate(0, "OM_dlgSLBg", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "OM_dlgSLBg", OBJPROP_XDISTANCE, cx);
   ObjectSetInteger(0, "OM_dlgSLBg", OBJPROP_YDISTANCE, cy);
   ObjectSetInteger(0, "OM_dlgSLBg", OBJPROP_XSIZE, w);
   ObjectSetInteger(0, "OM_dlgSLBg", OBJPROP_YSIZE, h);
   ObjectSetInteger(0, "OM_dlgSLBg", OBJPROP_BGCOLOR, clrWhiteSmoke);
   // Create dialog labels
   ObjectCreate(0, OM_lblSLTitle, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OM_lblSLTitle, OBJPROP_XDISTANCE, cx + 10);
   ObjectSetInteger(0, OM_lblSLTitle, OBJPROP_YDISTANCE, cy + 10);
   ObjectSetString(0, OM_lblSLTitle, OBJPROP_TEXT, "Stop Loss (Precio):");
   ObjectSetInteger(0, OM_lblSLTitle, OBJPROP_COLOR, clrBlack);
   // Create dialog inputs
   ObjectCreate(0, OM_editSLName, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, OM_editSLName, OBJPROP_XDISTANCE, cx + 10);
   ObjectSetInteger(0, OM_editSLName, OBJPROP_YDISTANCE, cy + 35);
   ObjectSetInteger(0, OM_editSLName, OBJPROP_XSIZE, w - 20);
   ObjectSetInteger(0, OM_editSLName, OBJPROP_YSIZE, 30);
   ObjectSetString(0, OM_editSLName, OBJPROP_TEXT, DoubleToString(Bid, Digits));
   ObjectSetInteger(0, OM_editSLName, OBJPROP_ALIGN, ALIGN_CENTER);
   OM_CreateDlgBtn(OM_btnSLConfirm, "Confirmar", cx + 10, cy + 75, 110, 30, clrGreen);
   OM_CreateDlgBtn(OM_btnSLCancel, "Cancelar", cx + 130, cy + 75, 110, 30, clrGray);
   OM_showingSLDialog = true;
}

void OM_HideSLDialog()
{
   ObjectDelete(0, "OM_dlgSLBg");
   ObjectDelete(0, OM_lblSLTitle);
   ObjectDelete(0, OM_editSLName);
   ObjectDelete(0, OM_btnSLConfirm);
   ObjectDelete(0, OM_btnSLCancel);
   OM_showingSLDialog = false;
}

// Button creator del panel Order Manager
void OM_CreateDlgBtn(string name, string text, int x, int y, int w, int h, color bg)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, OM_ButtonTextColor);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void OM_ProcessTPInput()
{
   double price = StringToDouble(ObjectGetString(0, OM_editTPName, OBJPROP_TEXT));
   OM_HideTPDialog();
   if (price >= 0)
      OM_SetTakeProfitToAll(price);
}

void OM_ProcessSLInput()
{
   double price = StringToDouble(ObjectGetString(0, OM_editSLName, OBJPROP_TEXT));
   OM_HideSLDialog();
   if (price >= 0)
      OM_SetStopLossToAll(price);
}

void OM_DeleteAllObjects()
{
   ObjectsDeleteAll(0, "OM_");
   OM_HideTPDialog();
   OM_HideSLDialog();
}

//+------------------------------------------------------------------+
//| LÓGICA DE TRADING                                                 |
//+------------------------------------------------------------------+
void OM_CloseAllOrders()
{
   if (!IsTradeAllowed())
      return;
   RefreshRates();
   int total = OrdersTotal(), closed = 0;
   string sym = Symbol();

   for (int i = total - 1; i >= 0; i--)
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == sym)
      {
         if (OrderType() == OP_BUY)
         {
            if (OrderClose(OrderTicket(), OrderLots(), Bid, SLIPERAGE_PIPS, clrRed))
               closed++;
         }
         else if (OrderType() == OP_SELL)
         {
            if (OrderClose(OrderTicket(), OrderLots(), Ask, SLIPERAGE_PIPS, clrRed))
               closed++;
         }
      }
   }

   Print("Cerradas ", closed, " órdenes.");
}

void OM_CloseProfitableOrders()
{
   if (!IsTradeAllowed())
      return;
   RefreshRates();
   int total = OrdersTotal(), closed = 0;
   string sym = Symbol();
   for (int i = total - 1; i >= 0; i--)
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == sym)
      {
         if (OrderProfit() + OrderSwap() + OrderCommission() > 0)
         {
            if (OrderType() == OP_BUY)
            {
               if (OrderClose(OrderTicket(), OrderLots(), Bid, SLIPERAGE_PIPS, clrGreen))
                  closed++;
            }
            else if (OrderType() == OP_SELL)
            {
               if (OrderClose(OrderTicket(), OrderLots(), Ask, SLIPERAGE_PIPS, clrGreen))
                  closed++;
            }
         }
      }
   }
   Print("Cerradas ", closed, " órdenes en profit.");
}

void OM_SetTakeProfitToAll(double tpPrice)
{
   if (!IsTradeAllowed())
      return;
   RefreshRates();
   int total = OrdersTotal(), modified = 0;
   string sym = Symbol();
   bool removeTP = (tpPrice == 0);
   double normalizedTP = removeTP ? 0 : NormalizeDouble(tpPrice, Digits);

   for (int i = total - 1; i >= 0; i--)
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == sym)
      {
         int orderType = OrderType();

         // Órdenes de mercado (BUY, SELL)
         if (orderType == OP_BUY || orderType == OP_SELL)
         {
            if (OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), normalizedTP, 0, clrBlue))
               modified++;
         }
         // Órdenes pendientes (BUYLIMIT, SELLLIMIT, BUYSTOP, SELLSTOP)
         else if (orderType == OP_BUYLIMIT || orderType == OP_SELLLIMIT ||
                  orderType == OP_BUYSTOP || orderType == OP_SELLSTOP)
         {
            if (OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), normalizedTP, OrderExpiration(), clrBlue))
               modified++;
         }
      }
   }

   if (removeTP)
      Print("Eliminados TPs de ", modified, " órdenes");
   else
      Print("Modificados ", modified, " TPs a precio ", DoubleToString(normalizedTP, Digits));
}

void OM_SetStopLossToAll(double slPrice)
{
   if (!IsTradeAllowed())
      return;
   RefreshRates();
   int total = OrdersTotal(), modified = 0;
   string sym = Symbol();
   bool removeSL = (slPrice == 0);
   double normalizedSL = removeSL ? 0 : NormalizeDouble(slPrice, Digits);

   for (int i = total - 1; i >= 0; i--)
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == sym)
      {
         int orderType = OrderType();

         // Órdenes de mercado (BUY, SELL)
         if (orderType == OP_BUY || orderType == OP_SELL)
         {
            if (OrderModify(OrderTicket(), OrderOpenPrice(), normalizedSL, OrderTakeProfit(), 0, clrRed))
               modified++;
         }
         // Órdenes pendientes (BUYLIMIT, SELLLIMIT, BUYSTOP, SELLSTOP)
         else if (orderType == OP_BUYLIMIT || orderType == OP_SELLLIMIT ||
                  orderType == OP_BUYSTOP || orderType == OP_SELLSTOP)
         {
            if (OrderModify(OrderTicket(), OrderOpenPrice(), normalizedSL, OrderTakeProfit(), OrderExpiration(), clrRed))
               modified++;
         }
      }
   }

   if (removeSL)
      Print("Eliminados SLs de ", modified, " órdenes");
   else
      Print("Modificados ", modified, " SLs a precio ", DoubleToString(normalizedSL, Digits));
}
