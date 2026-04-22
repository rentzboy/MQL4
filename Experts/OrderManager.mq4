//+------------------------------------------------------------------+
//|                                           OrderManagerEA.mq4      |
//|                                     Expert Advisor con Controles  |
//+------------------------------------------------------------------+
#property copyright "Order Manager EA"
#property link      ""
#property version   "2.00"
#property strict

// Parámetros de entrada
int ButtonWidth = 120;
int ButtonHeight = 25;
int PanelMarginLeft = 10;
color ButtonTextColor = clrWhite;
color PanelBgColor = clrBlack;

// Variables globales de nombres de objetos
string btnToggleName = "btnTogglePanel";
string panelBgName = "objPanelBackground";
string btnCloseAll = "btnCloseAll";
string btnCloseProfits = "btnCloseProfits";
string btnSetTP = "btnSetTP";
string btnSetSL = "btnSetSL";

// Variables para diálogos
string editTPName = "editTPInput", editSLName = "editSLInput";
string btnTPConfirm = "btnTPConfirm", btnTPCancel = "btnTPCancel";
string btnSLConfirm = "btnSLConfirm", btnSLCancel = "btnSLCancel";
string lblTPTitle = "lblTPTitle", lblSLTitle = "lblSLTitle";

bool panelVisible = false;
bool showingTPDialog = false;
bool showingSLDialog = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   DeleteAllObjects();
   UpdateUI();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { DeleteAllObjects(); }
void OnTick() {}

//+------------------------------------------------------------------+
//| ChartEvent function                                                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // BOTÓN DESPLEGABLE
      if(sparam == btnToggleName)
      {
         panelVisible = !panelVisible;
         UpdateUI();
         // IMPORTANTE: Resetear estado para evitar color negro
         ObjectSetInteger(0, btnToggleName, OBJPROP_STATE, false);
         ChartRedraw();
         return;
      }
      
      if(panelVisible)
      {
         if(sparam == btnCloseAll) { CloseAllOrders(); ObjectSetInteger(0, btnCloseAll, OBJPROP_STATE, false); }
         else if(sparam == btnCloseProfits) { CloseProfitableOrders(); ObjectSetInteger(0, btnCloseProfits, OBJPROP_STATE, false); }
         else if(sparam == btnSetTP) { ShowTPDialog(); ObjectSetInteger(0, btnSetTP, OBJPROP_STATE, false); }
         else if(sparam == btnSetSL) { ShowSLDialog(); ObjectSetInteger(0, btnSetSL, OBJPROP_STATE, false); }
      }
      
      if(sparam == btnTPConfirm) { ProcessTPInput(); ObjectSetInteger(0, btnTPConfirm, OBJPROP_STATE, false); }
      else if(sparam == btnTPCancel) { HideTPDialog(); ObjectSetInteger(0, btnTPCancel, OBJPROP_STATE, false); }
      else if(sparam == btnSLConfirm) { ProcessSLInput(); ObjectSetInteger(0, btnSLConfirm, OBJPROP_STATE, false); }
      else if(sparam == btnSLCancel) { HideSLDialog(); ObjectSetInteger(0, btnSLCancel, OBJPROP_STATE, false); }
      
      ChartRedraw();
   }
   
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(sparam == editTPName && showingTPDialog) ProcessTPInput();
      else if(sparam == editSLName && showingSLDialog) ProcessSLInput();
   }
}

//+------------------------------------------------------------------+
//| Actualizar UI con Gestión de Capas                                |
//+------------------------------------------------------------------+
void UpdateUI()
{
   // 1. ELIMINAR OBJETOS DEL PANEL PARA REORDENAR CAPAS
   ObjectDelete(0, panelBgName);
   ObjectDelete(0, btnCloseAll);
   ObjectDelete(0, btnCloseProfits);
   ObjectDelete(0, btnSetTP);
   ObjectDelete(0, btnSetSL);
   
   // 2. CREAR FONDO PRIMERO (CAPA INFERIOR)
   if(panelVisible)
   {
      int panelH = (ButtonHeight + 5) * 4 + 45; // Espacio para botones + toggle + márgenes
      ObjectCreate(0, panelBgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, panelBgName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, panelBgName, OBJPROP_XDISTANCE, PanelMarginLeft);
      ObjectSetInteger(0, panelBgName, OBJPROP_YDISTANCE, 25); // Desde la base
      ObjectSetInteger(0, panelBgName, OBJPROP_XSIZE, ButtonWidth + 20);
      ObjectSetInteger(0, panelBgName, OBJPROP_YSIZE, panelH);
      ObjectSetInteger(0, panelBgName, OBJPROP_BGCOLOR, PanelBgColor);
      ObjectSetInteger(0, panelBgName, OBJPROP_COLOR, clrDimGray);
      ObjectSetInteger(0, panelBgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, panelBgName, OBJPROP_BACK, false);
   }

   // 3. RECREAR BOTÓN TOGGLE (CAPA MEDIA)
   // Lo borramos y recreamos para que quede ENCIMA del fondo
   ObjectDelete(0, btnToggleName);
   ObjectCreate(0, btnToggleName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, btnToggleName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, btnToggleName, OBJPROP_XDISTANCE, PanelMarginLeft + 5);
   ObjectSetInteger(0, btnToggleName, OBJPROP_YDISTANCE, 25);
   ObjectSetInteger(0, btnToggleName, OBJPROP_XSIZE, ButtonWidth);
   ObjectSetInteger(0, btnToggleName, OBJPROP_YSIZE, 20);
   ObjectSetInteger(0, btnToggleName, OBJPROP_BGCOLOR, clrGray);
   ObjectSetInteger(0, btnToggleName, OBJPROP_COLOR, ButtonTextColor);
   ObjectSetInteger(0, btnToggleName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, btnToggleName, OBJPROP_TEXT, (panelVisible ? "Order Manager ▲" : "Order Manager ▼"));
   ObjectSetInteger(0, btnToggleName, OBJPROP_STATE, false);

   // 4. CREAR BOTONES DE GESTIÓN (CAPA SUPERIOR)
   if(panelVisible)
   {
      int x = PanelMarginLeft + 10;
      int y = 10 + 20 + 25; // toggleY + toggleH + gap
      
      CreateManagedButton(btnSetSL, "Set SL Global", x, y, ButtonWidth, ButtonHeight, clrOrangeRed);
      y += ButtonHeight + 5;
      CreateManagedButton(btnSetTP, "Set TP Global", x, y, ButtonWidth, ButtonHeight, clrDodgerBlue);
      y += ButtonHeight + 5;
      CreateManagedButton(btnCloseProfits, "Close Profits", x, y, ButtonWidth, ButtonHeight, clrForestGreen);
      y += ButtonHeight + 5;
      CreateManagedButton(btnCloseAll, "Close all", x, y, ButtonWidth, ButtonHeight, clrCrimson);
   }
   
   ChartRedraw();
}

void CreateManagedButton(string name, string text, int x, int y, int w, int h, color bg)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, ButtonTextColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
}

//+------------------------------------------------------------------+
//| DIÁLOGOS Y LÓGICA DE TRADING                                      |
//+------------------------------------------------------------------+
void ShowTPDialog()
{
   if(showingTPDialog) return;
   int dialogWidth = 250, dialogHeight = 130;
   int centerX = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS)/2 - dialogWidth/2;
   int centerY = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS)/2 - dialogHeight/2;
   ObjectCreate(0, "dlgTPBackground", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "dlgTPBackground", OBJPROP_XDISTANCE, centerX);
   ObjectSetInteger(0, "dlgTPBackground", OBJPROP_YDISTANCE, centerY);
   ObjectSetInteger(0, "dlgTPBackground", OBJPROP_XSIZE, dialogWidth);
   ObjectSetInteger(0, "dlgTPBackground", OBJPROP_YSIZE, dialogHeight);
   ObjectSetInteger(0, "dlgTPBackground", OBJPROP_BGCOLOR, clrWhiteSmoke);
   ObjectCreate(0, lblTPTitle, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, lblTPTitle, OBJPROP_XDISTANCE, centerX+10);
   ObjectSetInteger(0, lblTPTitle, OBJPROP_YDISTANCE, centerY+10);
   ObjectSetString(0, lblTPTitle, OBJPROP_TEXT, "Take Profit (Precio):");
   ObjectSetInteger(0, lblTPTitle, OBJPROP_COLOR, clrBlack);
   ObjectCreate(0, editTPName, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, editTPName, OBJPROP_XDISTANCE, centerX+10);
   ObjectSetInteger(0, editTPName, OBJPROP_YDISTANCE, centerY+35);
   ObjectSetInteger(0, editTPName, OBJPROP_XSIZE, dialogWidth-20);
   ObjectSetInteger(0, editTPName, OBJPROP_YSIZE, 30);
   ObjectSetString(0, editTPName, OBJPROP_TEXT, DoubleToString(Ask, Digits));
   ObjectSetInteger(0, editTPName, OBJPROP_ALIGN, ALIGN_CENTER);
   CreateDialogButton(btnTPConfirm, "Confirmar", centerX+10, centerY+75, 110, 30, clrGreen);
   CreateDialogButton(btnTPCancel, "Cancelar", centerX+130, centerY+75, 110, 30, clrGray);
   showingTPDialog = true;
   ChartRedraw();
}

void HideTPDialog() {
   ObjectDelete(0, "dlgTPBackground"); ObjectDelete(0, lblTPTitle); ObjectDelete(0, editTPName);
   ObjectDelete(0, btnTPConfirm); ObjectDelete(0, btnTPCancel); showingTPDialog = false;
   ChartRedraw();
}

void ShowSLDialog()
{
   if(showingSLDialog) return;
   int dialogWidth = 250, dialogHeight = 130;
   int centerX = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS)/2 - dialogWidth/2;
   int centerY = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS)/2 - dialogHeight/2;
   ObjectCreate(0, "dlgSLBackground", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "dlgSLBackground", OBJPROP_XDISTANCE, centerX);
   ObjectSetInteger(0, "dlgSLBackground", OBJPROP_YDISTANCE, centerY);
   ObjectSetInteger(0, "dlgSLBackground", OBJPROP_XSIZE, dialogWidth);
   ObjectSetInteger(0, "dlgSLBackground", OBJPROP_YSIZE, dialogHeight);
   ObjectSetInteger(0, "dlgSLBackground", OBJPROP_BGCOLOR, clrWhiteSmoke);
   ObjectCreate(0, lblSLTitle, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, lblSLTitle, OBJPROP_XDISTANCE, centerX+10);
   ObjectSetInteger(0, lblSLTitle, OBJPROP_YDISTANCE, centerY+10);
   ObjectSetString(0, lblSLTitle, OBJPROP_TEXT, "Stop Loss (Precio):");
   ObjectSetInteger(0, lblSLTitle, OBJPROP_COLOR, clrBlack);
   ObjectCreate(0, editSLName, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, editSLName, OBJPROP_XDISTANCE, centerX+10);
   ObjectSetInteger(0, editSLName, OBJPROP_YDISTANCE, centerY+35);
   ObjectSetInteger(0, editSLName, OBJPROP_XSIZE, dialogWidth-20);
   ObjectSetInteger(0, editSLName, OBJPROP_YSIZE, 30);
   ObjectSetString(0, editSLName, OBJPROP_TEXT, DoubleToString(Bid, Digits));
   ObjectSetInteger(0, editSLName, OBJPROP_ALIGN, ALIGN_CENTER);
   CreateDialogButton(btnSLConfirm, "Confirmar", centerX+10, centerY+75, 110, 30, clrGreen);
   CreateDialogButton(btnSLCancel, "Cancelar", centerX+130, centerY+75, 110, 30, clrGray);
   showingSLDialog = true;
   ChartRedraw();
}

void HideSLDialog() {
   ObjectDelete(0, "dlgSLBackground"); ObjectDelete(0, lblSLTitle); ObjectDelete(0, editSLName);
   ObjectDelete(0, btnSLConfirm); ObjectDelete(0, btnSLCancel); showingSLDialog = false;
   ChartRedraw();
}

void CreateDialogButton(string name, string text, int x, int y, int w, int h, color bg) {
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, ButtonTextColor);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void ProcessTPInput() {
   double price = StringToDouble(ObjectGetString(0, editTPName, OBJPROP_TEXT));
   HideTPDialog(); 
   // Permitir 0 para eliminar todos los TP
   if(price >= 0) SetTakeProfitToAll(price);
}

void ProcessSLInput() {
   double price = StringToDouble(ObjectGetString(0, editSLName, OBJPROP_TEXT));
   HideSLDialog(); 
   // Permitir 0 para eliminar todos los SL
   if(price >= 0) SetStopLossToAll(price);
}

void DeleteAllObjects() {
   ObjectDelete(0, btnToggleName); ObjectDelete(0, panelBgName);
   ObjectDelete(0, btnCloseAll); ObjectDelete(0, btnCloseProfits);
   ObjectDelete(0, btnSetTP); ObjectDelete(0, btnSetSL);
   HideTPDialog(); HideSLDialog();
}

void CloseAllOrders() {
   if(!IsTradeAllowed()) return;
   RefreshRates(); int total = OrdersTotal(), closed = 0; string sym = Symbol();
   for(int i = total-1; i >= 0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == sym) {
         if(OrderType() == OP_BUY) { if(OrderClose(OrderTicket(), OrderLots(), Bid, 3, clrRed)) closed++; }
         else if(OrderType() == OP_SELL) { if(OrderClose(OrderTicket(), OrderLots(), Ask, 3, clrRed)) closed++; }
      }
   }
   Print("Cerradas ", closed, " órdenes.");
}

void CloseProfitableOrders() {
   if(!IsTradeAllowed()) return;
   RefreshRates(); int total = OrdersTotal(), closed = 0; string sym = Symbol();
   for(int i = total-1; i >= 0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == sym) {
         if(OrderProfit() + OrderSwap() + OrderCommission() > 0) {
            if(OrderType() == OP_BUY) { if(OrderClose(OrderTicket(), OrderLots(), Bid, 3, clrGreen)) closed++; }
            else if(OrderType() == OP_SELL) { if(OrderClose(OrderTicket(), OrderLots(), Ask, 3, clrGreen)) closed++; }
         }
      }
   }
   Print("Cerradas ", closed, " órdenes en profit.");
}

void SetTakeProfitToAll(double tpPrice) {
   if(!IsTradeAllowed()) return;
   RefreshRates(); 
   int total = OrdersTotal(), modified = 0; 
   string sym = Symbol();
   
   // Si el precio es 0, eliminar todos los TP
   bool removeTP = (tpPrice == 0);
   double normalizedTP = 0;
   
   if(!removeTP)
      normalizedTP = NormalizeDouble(tpPrice, Digits);
   
   for(int i = total-1; i >= 0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == sym) {
         if(OrderType() == OP_BUY || OrderType() == OP_SELL) {
            if(OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), normalizedTP, 0, clrBlue)) 
               modified++;
         }
      }
   }
   
   if(removeTP)
      Print("Eliminados TPs de ", modified, " órdenes");
   else
      Print("Modificados ", modified, " TPs a precio ", DoubleToString(normalizedTP, Digits));
}

void SetStopLossToAll(double slPrice) {
   if(!IsTradeAllowed()) return;
   RefreshRates(); 
   int total = OrdersTotal(), modified = 0; 
   string sym = Symbol();
   
   // Si el precio es 0, eliminar todos los SL
   bool removeSL = (slPrice == 0);
   double normalizedSL = 0;
   
   if(!removeSL)
      normalizedSL = NormalizeDouble(slPrice, Digits);
   
   for(int i = total-1; i >= 0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == sym) {
         if(OrderType() == OP_BUY || OrderType() == OP_SELL) {
            if(OrderModify(OrderTicket(), OrderOpenPrice(), normalizedSL, OrderTakeProfit(), 0, clrRed)) 
               modified++;
         }
      }
   }
   
   if(removeSL)
      Print("Eliminados SLs de ", modified, " órdenes");
   else
      Print("Modificados ", modified, " SLs a precio ", DoubleToString(normalizedSL, Digits));
}
