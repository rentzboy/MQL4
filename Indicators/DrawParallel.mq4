#property indicator_chart_window

input double OffsetPoints = 100;

string ButtonName = "DrawParallelBtn";

int OnInit()
{
   ObjectCreate(0, ButtonName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ButtonName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, ButtonName, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, ButtonName, OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, ButtonName, OBJPROP_YSIZE, 25);
   ObjectSetString(0, ButtonName, OBJPROP_TEXT, "Linea paralela");

   return INIT_SUCCEEDED;
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == ButtonName)
   {
      DrawParallel();
   }
}

void DrawParallel()
{
   string objName = ObjectName(0, 0, -1);
   if(objName == "") return;

   if(ObjectGetInteger(0, objName, OBJPROP_TYPE) != OBJ_TREND)
      return;

   datetime t1 = ObjectGetInteger(0, objName, OBJPROP_TIME1);
   datetime t2 = ObjectGetInteger(0, objName, OBJPROP_TIME2);
   double p1 = ObjectGetDouble(0, objName, OBJPROP_PRICE1);
   double p2 = ObjectGetDouble(0, objName, OBJPROP_PRICE2);

   double offset = OffsetPoints * _Point;

   ObjectCreate(0, objName + "_parallel", OBJ_TREND, 0,
                t1, p1 + offset,
                t2, p2 + offset);
}