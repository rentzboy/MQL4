//Show the indicator in the chart window
//#property indicator_chart_window => da error
#property strict
//Required -for scripts only- to display a window with the properties when attaching the script
#property script_show_inputs
//nuestra el nombre del EA en la esquina superior derecha
#property indicator_chart_window 

// Importamos la función desde la librería del sistema de Windows
#import "user32.dll"
short GetAsyncKeyState(int nVirtKey);
#import

#define VK_ALT    18   // Cualquier tecla ALT
#define VK_LMENU  164  // ALT Izquierdo
#define VK_RMENU  165  // ALT GR (ALT Derecho)
#define OffsetBars 10   //Offset de las barras (# de barras entre x1,y1 y x2,y2)
#define OffsetText 5    //Distancia a la que se numeran las velas desde el máx.

//Input keyword para los parámetros que se asignan desde el pop-up (F7)
input int OffsetPoints = 25;   // Desplazamiento en puntos

struct trendLineToCoppy {
   string name;
   color lineColor;
   int   lineWidth;
   int   lineStyle;
   long  lineTimeFrame;
   datetime t1;
   datetime t2;
   double p1;
   double p2;
   double offset;
   int multiple; //Distancia entre paralelas
   int offsetCounter;
};

string ButtonName = "DrawParallelBtn";
trendLineToCoppy trendLineYellow, trendLineBlue, trendLineBrown;
trendLineToCoppy lineasTendencia[3];

// OnTick solo está activo en los Expert Advisor, pero lo dejo para quitar el error: "OnCalculate not found"
void OnTick() {}

// Initialization
int OnInit()
{
   ObjectCreate(0, ButtonName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ButtonName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, ButtonName, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, ButtonName, OBJPROP_XSIZE, 100);
   ObjectSetInteger(0, ButtonName, OBJPROP_YSIZE, 25);
   ObjectSetInteger(0, ButtonName, OBJPROP_COLOR, clrWhite);          // Color del texto
   ObjectSetInteger(0, ButtonName, OBJPROP_BGCOLOR, clrOrange);   // Color de fondo
   ObjectSetString(0, ButtonName, OBJPROP_TEXT, "Paralela");
   ObjectSetInteger(0, ButtonName, OBJPROP_STATE, false); //IMPORTANTE

   InitTrendLines();

   return INIT_SUCCEEDED;
}

// De-initialization
void OnDeinit(const int reason)
{
   // Borramos el botón al quitar el EA del gráfico
   ObjectDelete(0, ButtonName);
}

//+--------------------------------------------------+
//| Gestión de eventos (CON DELAY)                   |
//+--------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Manual Offset
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == ButtonName)
   {
      Sleep(20);
      DrawManualParallel();
      ObjectSetInteger(0, ButtonName, OBJPROP_STATE, false);
   }
   
   //Solamente para recuperar los datos de las trendlines a copiar, luego comentar
   /*
   if(id == CHARTEVENT_OBJECT_CLICK && ObjectGet(sparam, OBJPROP_TYPE) == OBJ_TREND)
   {
      //Vamos a calcular t1 y p1 a 10 barras de t2, para calcular el offset
      datetime t1 = (datetime)ObjectGetInteger(0, sparam, OBJPROP_TIME, 0);
      double p1   = ObjectGetDouble(0, sparam, OBJPROP_PRICE, 0);
      datetime t2 = (datetime)ObjectGetInteger(0, sparam, OBJPROP_TIME, 1);
      double p2   = ObjectGetDouble(0, sparam, OBJPROP_PRICE, 1);
      
      int barIndext2 = iBarShift(NULL, 0, t2, false);
      datetime t3 = iTime(NULL, 0, barIndext2 + OffsetBars); //+10 barras hacia atrás
      double p3 = ObjectGetValueByTime(0, sparam, t3);


      PrintFormat("t1: %s - t2: %s - t3: %s", TimeToString(t1), TimeToString(t2), TimeToString(t3));
      PrintFormat("p1: %f - p2: %f - p3: %f", p1, p2, p3);

      double offset = p2 - p3;
      PrintFormat("Offset: %f", offset);
   }
   */

   // Auto Offset => Hay que activar Permitir importar DLL para que funcione en el EA
   if(id == CHARTEVENT_CLICK && (GetAsyncKeyState(VK_RMENU) & 0x8000) != 0)
   {
      int barIndex = GetSelectedBarIndex(lparam, dparam);
      //PrintFormat("Click: sparam %s - lparam %d - dparam %f", sparam, lparam, dparam);
      DrawAutomaticParallel(barIndex);
      Sleep(10);
   }  
}

int GetSelectedBarIndex(const long &lparam, const double &dparam)
{
   //Obtener las coordenadas del clic
   int x = (int)lparam; // Coordenada X en píxeles
   int y = (int)dparam; // Coordenada Y en píxeles (no la usaremos para la barra, pero es necesaria)

   int      sub_window; // Se llenará con el índice de la ventana (0 = principal)
   datetime time;       // Se llenará con la fecha correspondiente al píxel X
   double   price;      // Se llenará con el precio correspondiente al píxel Y

   //Convertir Píxeles X,Y a Tiempo y Precio
   if(ChartXYToTimePrice(0, x, y, sub_window, time, price) != true) Alert("Error de ChartXYToTimePrice()");
   {
      // Convertir el Tiempo a Índice de Barra
      // exact = false para que nos dé la barra más cercana si no clicamos justo al inicio
      int barIndex = iBarShift(NULL, 0, time, false);
      PrintFormat("Clic en X:%d | Fecha: %s | Índice de Barra: %d", x, TimeToString(time), barIndex);
      return barIndex;
   }
}

//+--------------------------------------------------+
//| Buscar línea de tendencia seleccionada (CON DELAY)|
//+--------------------------------------------------+
string GetSelectedLine()
{
   // Pequeño delay inicial para asegurar que la selección está registrada
   Sleep(20);
   
   int total = ObjectsTotal(0, 0, -1);
   
   string selectedLine = "";
   int countSelected = 0;
   
   // Recorrer todos los objetos
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      
      // Verificar que NO sea el botón
      if(name == ButtonName) continue; //vuelve al principio del loop
      
      // Verificar que esté seleccionado
      if(ObjectGetInteger(0, name, OBJPROP_SELECTED) == true)
      {
         // CRUCIAL: Verificar que sea una línea de tendencia || linea vertical
         int objType = (int)ObjectGetInteger(0, name, OBJPROP_TYPE);
         
         if(objType == OBJ_TREND || objType == OBJ_VLINE)
         {
            selectedLine = name;
            countSelected++;
            Print("Trendline seleccionada encontrada: ", name);
         }
         else
         {
            Alert("Objeto seleccionado pero NO es trendline: ", name, " (Tipo: ", objType, ")");
         }
      }
      
      if(countSelected > 1)
      {
         selectedLine = "multipleSelection";
         break;
      }
   }//End Loop
   
   return selectedLine;
}

//------------------------------
// Dibujar línea paralela manual
//------------------------------
void DrawManualParallel()
{
   string objName = GetSelectedLine();
   double offset=0;
   datetime t1=0, t2=0;
   double p1=0, p2=0;
   
   //Sanitation check
   if(objName == "")
   {
      Alert("No hay ninguna línea de tendencia seleccionada");
      return;
   }
   if(objName == "multipleSelection")
   {
      Alert("ADVERTENCIA: Hay varias trendlines seleccionadas.");
      return;
   }

   Sleep(20);

   //Recuperar los datos de la linea original: datetime & price
   color lineColor = (color)ObjectGetInteger(0, objName, OBJPROP_COLOR);
   int   lineWidth = (int)ObjectGetInteger(0, objName, OBJPROP_WIDTH);
   int   lineStyle = (int)ObjectGetInteger(0, objName, OBJPROP_STYLE);
   long  lineTime  = ObjectGetInteger(0, objName, OBJPROP_TIMEFRAMES);

   if(ObjectType(objName) == OBJ_VLINE)
   {
      t1 = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
      //PrintFormat("Datetime de la linea vertical: %s", TimeToString(t1, TIME_DATE|TIME_MINUTES));

      // Comprobar si la línea está en el futuro (iBarShift devuelve 0 si la barra no existe)
      if(t1 > Time[0])
      {
         Alert("ERROR: La línea está en el FUTURO. No se puede calcular el desplazamiento.");
         return; // Salimos de la función para no crear una línea errónea
      }

      int barIndex = iBarShift(NULL, 0, t1, false);

      t2 = iTime(NULL, 0, barIndex + OffsetPoints);
   }

   if(ObjectType(objName) == OBJ_TREND)
   {
      // Leer coordenadas INMEDIATAMENTE para evitar race conditions
      t1= (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0); //returns long
      t2 = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 1);
      p1 = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
      p2 = ObjectGetDouble(0, objName, OBJPROP_PRICE, 1);

      // Validar que las coordenadas sean válidas
      if(t1 == 0 || t2 == 0 || p1 == 0 || p2 == 0)
      {
      Alert("Error: Coordenadas de la línea inválidas");
      Print("t1=", t1, " t2=", t2, " p1=", p1, " p2=", p2);
      return;
      }
      offset = OffsetPoints * _Point;
   }

   // SOLUCIÓN: Generar nombre único GARANTIZADO
   string newName = "";
   bool nameFound = false;
   int attempt = 0;
   int maxAttempts = 10;
   
   while(!nameFound && attempt < maxAttempts)
   {
      // Combinar múltiples fuentes de aleatoriedad
      newName = "Parallel_" + IntegerToString(GetTickCount()) + 
                "_" + IntegerToString(MathRand()) + 
                "_" + IntegerToString(attempt);
      
      // Verificar si el nombre No está duplicado
      if(ObjectFind(0, newName) < 0) //If the object is not found, the function returns a negative number)
      {
         nameFound = true; //No duplicado
      }
      else
      {
         Print("Nombre duplicado detectado (intento ", attempt, "): ", newName);
         Sleep(5); // Pequeño delay para cambiar GetTickCount()
         attempt++;
      }
   }
   
   if(!nameFound)
   {
      Alert("Error: No se pudo generar un nombre único después de ", maxAttempts, " intentos");
      return;
   }
   
   //Print("Nombre único generado: ", newName);
   
   // Crear línea paralela
   bool created=0;
   if(ObjectType(objName) == OBJ_TREND)
   {
      created = ObjectCreate(0, newName, OBJ_TREND, 0,
                               t1, p1 + offset,
                               t2, p2 + offset);
   }

   if(ObjectType(objName) == OBJ_VLINE)
   {
      created = ObjectCreate(0, newName, OBJ_VLINE, 0, t2, 0); //para VLINE el precio se ignora
   }
   
   if(!created)
   {
      int error = GetLastError();
      Alert("Error al crear la línea paralela. Código: ", error);
      Print("Error details - Name: ", newName, " Error: ", error);
      return;
   }

   // Pequeño delay después de crear el objeto
   Sleep(10);

   // Aplicar propiedades de la linea original
   ObjectSetInteger(0, newName, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, newName, OBJPROP_WIDTH, lineWidth);
   ObjectSetInteger(0, newName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, newName, OBJPROP_TIMEFRAMES, lineTime);
   ObjectSetInteger(0, newName, OBJPROP_BACK, true);
   if(ObjectType(objName) == OBJ_TREND)
   {
      ObjectSetInteger(0, newName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, newName, OBJPROP_SELECTABLE, true);
   }
   Sleep(10);
   
   // Gestión de selección
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, newName, OBJPROP_SELECTED, true);
   Sleep(10);
   
   // Refrescar el gráfico
   ChartRedraw(0);
   
   Print("Línea paralela creada: ", newName);
}

//----------------------------------
// Dibujar línea paralela automática
//----------------------------------
void DrawAutomaticParallel(int barIndex)
{
   Print("DrawAutomaticParallel: barIndex=", barIndex);

   // Limpiar selección
   UnselectAllObjects();

   NumerarVelas(barIndex);
   
   for (int i = 0; i < ArraySize(lineasTendencia); i++)
   {
      //Recuperar el mínimo de la barra seleccionada
      double p2 = iLow(NULL, 0, barIndex);
      //Recuperar el datetime de la barra seleccionada
      datetime t2 = iTime(NULL, 0, barIndex);
      
      //Calcular las coordenadas del t1, p1 
      datetime t1 = iTime(NULL, 0, barIndex + OffsetBars);
      //Calcular el precio de la barra seleccionada
      double p1 = p2 - lineasTendencia[i].offset;

      //Crear la linea paralela desde mínimos
      string newLineName = lineasTendencia[i].name + IntegerToString(GetTickCount());
      //string newName = lineasTendencia[i].name + IntegerToString(GetTickCount()) + "_" + IntegerToString(MathRand());
      //Print("Crear linea paralela: ", newLineName, " t1=", t1, " t2=", t2, " p1=", p1, " p2=", p2);
      if(ObjectCreate(0, newLineName, OBJ_TREND, 0, t1, p1, t2, p2) == false)
      {
         int error = GetLastError();
         Alert("Error al crear la linea paralela. Código: ", error);
         Print("Error details - Name: ", newLineName, " Error: ", error);
         return;
      };
     
      Sleep(10);
      //Aplicar propiedades de la linea original
      ObjectSetInteger(0, newLineName, OBJPROP_COLOR, lineasTendencia[i].lineColor);
      ObjectSetInteger(0, newLineName, OBJPROP_WIDTH, lineasTendencia[i].lineWidth);
      ObjectSetInteger(0, newLineName, OBJPROP_STYLE, lineasTendencia[i].lineStyle);
      ObjectSetInteger(0, newLineName, OBJPROP_TIMEFRAMES, lineasTendencia[i].lineTimeFrame);
      ObjectSetInteger(0, newLineName, OBJPROP_BACK, true);
      ObjectSetInteger(0, newLineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, newLineName, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, newLineName, OBJPROP_SELECTED, true);

      //Offsets de las lineas de tª desde el minimo
      for (int ii = 1; ii < lineasTendencia[i].offsetCounter + 1; ii++)
      {
         //Para las offset brown, saltarse las offsets a 5 y 7 pips
         if(lineasTendencia[i].name == "trendLineBrown")
         {
            if(ii == 5 || ii == 7)
            {
               continue;
            }
         }

         string newParallelName = newLineName + IntegerToString(ii);
         double offset = lineasTendencia[i].multiple * _Point * ii; //Warning i -not ii-

         if(ObjectCreate(0, newParallelName, OBJ_TREND, 0, t1, p1 + offset, t2, p2 + offset) == false)
         {
         int error = GetLastError();
         Alert("Error al crear la linea paralela. Código: ", error);
         Print("Error details - Name: ", newLineName, " Error: ", error);
         }
         //Aplicar propiedades de la linea original
         ObjectSetInteger(0, newParallelName, OBJPROP_COLOR, lineasTendencia[i].lineColor);
         ObjectSetInteger(0, newParallelName, OBJPROP_WIDTH, lineasTendencia[i].lineWidth);
         ObjectSetInteger(0, newParallelName, OBJPROP_STYLE, lineasTendencia[i].lineStyle);
         ObjectSetInteger(0, newParallelName, OBJPROP_TIMEFRAMES, lineasTendencia[i].lineTimeFrame);
         ObjectSetInteger(0, newParallelName, OBJPROP_BACK, true);
         ObjectSetInteger(0, newParallelName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, newParallelName, OBJPROP_SELECTABLE, true);
         ObjectSetInteger(0, newParallelName, OBJPROP_SELECTED, true);

         // Gestión de selección
         ObjectSetInteger(0, newParallelName, OBJPROP_SELECTED, false);
         Sleep(10);
      }
      ObjectSetInteger(0, newLineName, OBJPROP_SELECTED, false);
   }
   //Refrescar el gráfico
   ChartRedraw(0);
}

//----------------------------------
// Auxiliary functions
//----------------------------------
void UnselectAllObjects(void)
{
   int total = ObjectsTotal(0, 0, -1);
   
   string selectedLine = "";
   int countSelected = 0;
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      
      //De-seleccionar cualquier objeto
      if(ObjectGetInteger(0, name, OBJPROP_SELECTED) == true)
         ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   }
}

void NumerarVelas(int indexBar)
{
   
   //Vamos a numerar 3 ondas:
   for (int i = 2; i < 10; i++)
   {
      //Recuperar el máximo y el datetime de la barra seleccionada
      double p1 = iHigh(NULL, 0, indexBar + i) + OffsetText * _Point;
      datetime t1 = iTime(NULL, 0, indexBar + i);

      string newTextName = "Onda_" + IntegerToString(i + 1) + "_" + IntegerToString(GetTickCount());

      ObjectCreate(0, newTextName, OBJ_TEXT, 0, t1, p1);
      ObjectSetInteger(0, newTextName, OBJPROP_COLOR, LightSteelBlue);          // Color del texto
      ObjectSetInteger(0, newTextName, OBJPROP_BGCOLOR, clrOrange);   // Color de fondo
      ObjectSetInteger(0, newTextName, OBJPROP_TIMEFRAMES, OBJ_PERIOD_M1);
      ObjectSetInteger(0, newTextName, OBJPROP_FONTSIZE, 10); 
      ObjectSetInteger(0, newTextName, OBJPROP_SELECTED, false);
      ObjectSetString(0, newTextName, OBJPROP_TEXT, IntegerToString(i + 1));
      i += 2;
   }
   





}

void InitTrendLines()
{
   //YELLOW
   trendLineYellow.name      = "trendLineYellow";
   trendLineYellow.lineColor = clrYellow;
   trendLineYellow.lineWidth = 1;
   trendLineYellow.lineStyle = STYLE_DOT;
   trendLineYellow.lineTimeFrame = OBJ_PERIOD_M1;
   trendLineYellow.t1        = D'2026.04.21 22:27';
   trendLineYellow.t2        = D'2026.04.21 22:43';
   trendLineYellow.p1        = 1.172028;
   trendLineYellow.p2        = 1.172131;
   trendLineYellow.offset    = 0.000064; //Offset para calcular p1 a partir de p2
   trendLineYellow.multiple  = 25; //Distancia entre paralelas
   trendLineYellow.offsetCounter = 4;
   
   //LIGHTSKYBLUE
   trendLineBlue.name      = "trendLineBlue";
   trendLineBlue.lineColor = LightSkyBlue;
   trendLineBlue.lineWidth = 1;
   trendLineBlue.lineStyle = STYLE_DOT;
   trendLineBlue.lineTimeFrame = OBJ_PERIOD_M1;
   trendLineBlue.t1        = D'2026.04.21 22:27';
   trendLineBlue.t2        = D'2026.04.21 22:43';
   trendLineBlue.p1        = 1.171870;
   trendLineBlue.p2        = 1.172036;
   trendLineBlue.offset    = 0.000104;
   trendLineBlue.multiple  = 15;
   trendLineBlue.offsetCounter = 6;
   
   //BROWN
   trendLineBrown.name      = "trendLineBrown";
   trendLineBrown.lineColor = DarkKhaki;
   trendLineBrown.lineWidth = 1;
   trendLineBrown.lineStyle = STYLE_DOT;
   trendLineBrown.lineTimeFrame = OBJ_PERIOD_M1;
   trendLineBrown.t1        = D'2026.04.21 22:27';
   trendLineBrown.t2        = D'2026.04.21 22:43';
   trendLineBrown.p1        = 1.171828;
   trendLineBrown.p2        = 1.171879;
   trendLineBrown.offset    = 0.000032;
   trendLineBrown.multiple  = 10;
   trendLineBrown.offsetCounter = 8;

   lineasTendencia[0] = trendLineYellow;
   lineasTendencia[1] = trendLineBlue;
   lineasTendencia[2] = trendLineBrown;
}