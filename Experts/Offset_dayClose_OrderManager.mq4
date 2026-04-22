/* ES LA COMBINACIÓN DE 3 EA
   > OFFSET.mq4 -pintar paralelas a X distancia
   > NIVELESHORIZONTALES.mq4 - marca los cierres de las velas diarias y semanales
   > ORDERMANAGER.mq4 - cerrar/editar multiples ordens de take profit/stop loss, close all 
   */
#property strict
#property script_show_inputs
#property indicator_chart_window 

// INCLUSIÓN DEL GESTOR DE ÓRDENES (VERSION 2.00)
#include <OrderManager.mqh>

// Parámetros de Offset
input int OffsetPoints = 15;   // Desplazamiento en puntos

string ButtonName = "DrawParallelBtn";
int totalObjetos = 0; //global

struct nivelHorizontal
{
  string nombre;
  double precio;
  bool existe;
} cierre_H_1D ={"Cierre_1D", 0, false}, cierre_H_4H ={"Cierre_4H", 0, false}, cierre_H_1W ={"Cierre_1W", 0, false};

struct vela_t
{
  datetime timeStamp;
  double open;
  double high;
  double low;
  double close;
} vela_4H = {0, 0, 0, 0, 0}, vela_1D = {0, 0, 0, 0, 0}, vela_1W = {0, 0, 0, 0, 0};

//----------------------- FUNCIONES DE METATRADER -----------------------//
void OnTick() {}

// Initialization
int OnInit()
{
   // Inicializar Gestor de Órdenes (Esquina Inferior)
   OM_OnInit();

   // Inicializar Botón Paralela (Esquina Superior)
   ObjectCreate(0, ButtonName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ButtonName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, ButtonName, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, ButtonName, OBJPROP_XSIZE, 100);
   ObjectSetInteger(0, ButtonName, OBJPROP_YSIZE, 25);
   ObjectSetInteger(0, ButtonName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, ButtonName, OBJPROP_BGCOLOR, clrDodgerBlue);
   ObjectSetString(0, ButtonName, OBJPROP_TEXT, "Paralela");
   ObjectSetInteger(0, ButtonName, OBJPROP_STATE, false);

   actualizarNivelesCierreVelas();

   return INIT_SUCCEEDED;
}

// De-initialization
void OnDeinit(const int reason)
{
   // Desinicializar Gestor de Órdenes
   OM_OnDeinit();
   
   // Borramos el botón Paralela
   ObjectDelete(0, ButtonName);
}

// Gestión de eventos
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // 1. Procesar eventos del Gestor de Órdenes (Prioritario)
   OM_OnChartEvent(id, lparam, dparam, sparam);

   // 2. Procesar evento Botón Paralela
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == ButtonName)
   {
      Sleep(20);
      DrawParallel();
      ObjectSetInteger(0, ButtonName, OBJPROP_STATE, false);
      ChartRedraw();
   }
}

//----------------------- FUNCIONES DE OFFSET -----------------------//
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

void DrawParallel()
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

//----------------------- FUNCIONES DE CIERRE DE VELA -----------------------//
void actualizarNivelesCierreVelas(void)
{
  totalObjetos = ObjectsTotal(0, 0, OBJ_HLINE);
  buscarVelasCierreAnteriores();
  buscarNivelesHorizontalesCierre();
  actualizarNivelHorizontal();
}

bool buscarNivelesHorizontalesCierre(void)
{
   for(int i = totalObjetos-1; i >= 0 ; i--)
   {
      string nombreObjeto = ObjectName(0, i);
      if(nombreObjeto == cierre_H_1D.nombre) { cierre_H_1D.existe = true; cierre_H_1D.precio = ObjectGetDouble(0, nombreObjeto, OBJPROP_PRICE, 0); }
      if (nombreObjeto == cierre_H_1W.nombre) { cierre_H_1W.existe = true; cierre_H_1W.precio = ObjectGetDouble(0, nombreObjeto, OBJPROP_PRICE, 0); }
    }
    return (cierre_H_1D.existe && cierre_H_1W.existe);
}

bool buscarVelasCierreAnteriores(void)
{
  vela_1D.close = iClose(Symbol(), PERIOD_D1, 1);
  vela_1W.close = iClose(Symbol(), PERIOD_W1, 1);
  return (vela_1D.close > 0 && vela_1W.close > 0);
}

void actualizarNivelHorizontal(void)
{
  if (cierre_H_1D.precio != vela_1D.close) 
  {
    cierre_H_1D.precio = vela_1D.close;
    if (cierre_H_1D.existe) ActualizarLineaHorizontal(cierre_H_1D.nombre, vela_1D.close);
    else DibujarLineaHorizontal(cierre_H_1D.nombre, vela_1D.close, clrDarkKhaki, "Nivel_1D");
  }
  if (cierre_H_1W.precio != vela_1W.close) 
  {
    cierre_H_1W.precio = vela_1W.close;
    if (cierre_H_1W.existe) ActualizarLineaHorizontal(cierre_H_1W.nombre, vela_1W.close);
    else DibujarLineaHorizontal(cierre_H_1W.nombre, vela_1W.close, clrDarkOrange, "Nivel_1W");
  }
}

bool DibujarLineaHorizontal(string nombre, double precio, color colorLinea, string descripcion)
{
   if(ObjectCreate(0, nombre, OBJ_HLINE, 0, 0, precio))
   {
      ObjectSetString(0, nombre, OBJPROP_TEXT, descripcion);
      ObjectSetInteger(0, nombre, OBJPROP_COLOR, colorLinea);
      ObjectSetInteger(0, nombre, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, nombre, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetInteger(0, nombre, OBJPROP_BACK, true);
      ObjectSetInteger(0, nombre, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, nombre, OBJPROP_SELECTED, false);
      ChartRedraw(0);
      return true;
   }
   return false;
}

bool ActualizarLineaHorizontal(string nombre, double precio)
{
   if(ObjectFind(0, nombre) >= 0) { ObjectSetDouble(0, nombre, OBJPROP_PRICE, 0, precio); ChartRedraw(0); return true; }
   return false;
}