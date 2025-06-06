/*-----------------------------------------------------------------------------------------------------------------

El tipo SolutionData es el modelo de la representación formal de las soluciones del problema de los funcionarios. 
Proporciona las herramientas necesarias para verificar diferentes configuraciones de una solución.

Estructura del fichero:

  Datatype
  - employeesAssign: secuencia de enteros de tamaño número de funcionarios donde cada posición corresponde a 
    un funcionario y cuyo valor almacenado representa el tarea asignado a ese funcionario.
  - k: etapa del árbol de exploración de la solución. Denota el número de funcionarios tratados de employeesAssign 
    hasta el momento.

  Funciones
    - TotalTime: suma total de los tiempos que tardan todos los funcionaios en realizar cada uno de sus tareas.
  
  Predicados
    - Partial: una solución parcial es válida.
    - Valid: una solución completa es válida.
    - Optimal: una solución es óptima.
    - Extends: una solución extiende de otra.
    - OptimalExtension: una solución es extensión óptima de otra.
    - Equals: una solución es igual a otra (igualdad de campos).

-----------------------------------------------------------------------------------------------------------------------*/


include "InputData.dfy"

datatype SolutionData = SolutionData(employeesAssign : seq<int>, k : nat) {

  /* Funciones */

  /*
    Función: calcula el tiempo total que tardan los funcionarios en realizar sus tareas hasta el índice k.
  */
  ghost function TotalTime(times : seq<seq<real>>) : real
    decreases k
    requires Explicit(times)
  {
    if k == 0 then
      0.0
    else
      SolutionData(employeesAssign, k - 1).TotalTime(times) + times[k - 1][employeesAssign[k - 1]]
  }


  /* Predicados */

  /*
    Predicado: restricciones explícitas del problema.
  */
  ghost predicate Explicit(times: seq<seq<real>>)
  {
    && 0 <= k <= |employeesAssign| == |times|
    && (forall i | 0 <= i < |times| :: |times[i]| == |times|)
    && (forall i | 0 <= i < this.k :: 0 <= employeesAssign[i] < |employeesAssign|) // tareas válidas
  }


  /*
    Predicado: restricciones implícitas del problema.
  */
  ghost predicate Implicit(times: seq<seq<real>>)
    requires Explicit(times)
  {
    && (forall i,j | 0 <= i < this.k && 0 <= j < this.k && i != j :: employeesAssign[i] != employeesAssign[j])
  }


  /*
    Predicado: verifica que una solución parcial sea válida hasta el índice k.
  */
  ghost predicate Partial (input: InputData)
    requires input.Valid()
  {
    && Explicit(input.times)
    && Implicit(input.times)
  }


  /*
    Predicado: verifica que la solución esté completa (hemos tratado todos los funcionarios) y sea válida.
  */
  ghost predicate Valid(input: InputData)
    requires input.Valid()
  {
    && k == |employeesAssign|
    && Partial(input)
  }


  /*
    Predicado: asegura que una solución válida (this) sea óptima, es decir, que no exista ninguna otra solución 
    válida con un menor tiempo total.
  */
  ghost predicate Optimal(input: InputData)
    requires input.Valid()
    requires this.Valid(input)
  {
    forall s: SolutionData | s.Valid(input) :: s.TotalTime(input.times) >= TotalTime(input.times)
  }


  /*
    Predicado: verifica que una solución (this) extiende a la solución parcial (ps), manteniendo la igualdad 
    hasta el índice k.
  */
  ghost predicate Extends(ps: SolutionData)
    requires ps.k <= this.k <= |this.employeesAssign| == |ps.employeesAssign|
  {
    forall i | 0 <= i < ps.k :: this.employeesAssign[i] == ps.employeesAssign[i]
  }


  /*
    Predicado: verifica que una solución (this) es una extensión óptima de la solución parcial ps, garantizando que
    no haya soluciones válidas con un menor tiempo total que this.
  */
  ghost predicate OptimalExtension(ps : SolutionData, input : InputData)
    requires input.Valid()
  {
    && this.Valid(input)
    && ps.Partial(input)
    && this.Extends(ps)
    && forall s : SolutionData | && s.Valid(input)
                                 && s.Extends(ps)
         :: s.TotalTime(input.times) >= this.TotalTime(input.times)
  }

  /*
    Predicado: verifica que dos soluciones this y s sean iguales hasta el índice k, es decir, que cuentan con la 
    misma asignación de funcionarios.
  */
  ghost predicate Equals(s: SolutionData)
    requires this.k <= |this.employeesAssign| == |s.employeesAssign|
    requires s.k <= |s.employeesAssign|
  {
    && this.k == s.k
    && forall i | 0 <= i < this.k :: this.employeesAssign[i] == s.employeesAssign[i]
  }



  /* Lemas */

  /*
  Lema:  dada una solución s1 que se extiende añadiendo un elemento a true generando una nueva solución s2, 
  la suma de los tiempos de s2 se actualiza de manera consistente al incluir el tiempo del nuevo elemento.
  //
  Propósito: garantiza que la consistencia de los datos entre las versiones antigua y actual del modelo para 
  verificar un invariante del bucle que inicializa bs de la solución de Employees.dfy.
  //
  Demostración: mediante el lema EqualTimeFromEquals.
  */
  static lemma AddTimeMaintainsSumConsistency(s1 : SolutionData, s2 : SolutionData, input : InputData) // s1 viejo, s2 nuevo
    requires input.Valid()
    requires |s2.employeesAssign| == |s1.employeesAssign|
    requires s1.Explicit(input.times)
    requires s2.Explicit(input.times)
    requires 0 <= s1.k <= |s1.employeesAssign|
    requires 0 < s2.k <= |s2.employeesAssign|
    requires s2.k == s1.k + 1
    requires s1.employeesAssign[..s1.k] + [s2.employeesAssign[s1.k]] == s2.employeesAssign[..s2.k]
    ensures s1.TotalTime(input.times) + input.times[s1.k][s2.employeesAssign[s1.k]] == s2.TotalTime(input.times)
  {
    s1.EqualTimeFromEquals(SolutionData(s2.employeesAssign, s2.k-1), input);
  }

  /*
  Lema: dada una solución parcial ps, una solución completa s que extiende a ps, y un mínimo de la submatriz desde
  la fila row en adelante, el tiempo total de la solución completa s nunca excede la suma del tiempo de la solución
  parcial ps más el tiempo invertido por los funcionarios restantes de ps tardando el tiempo min.
  //
  Propósito: garantiza que el mínimo de la matriz por el resto de funcionarios es cota inferior.
  //
  Demostración: por inducción en la diferencia de índices entre s.k y ps.k, es decir, en el número de funcionarios
  que aún no ha asignado ps.
    - Caso base: ambas soluciones son equivalentes y por lo tanto también lo son sus tiempos totales.
    - Caso inductivo: ps se extiende a ps' según s en la posición ps.k, manteniendo la consistencia del tiempo con 
      AddTimeMaintainsSumConsistency. Por hipótesis inductiva:
                 s.TotalTime >= ps'.TotalTime + (n - ps.k - 1) * min >= ps.TotalTime + (n - ps.k) * min
  */
  static lemma AddTimesLowerBound(ps : SolutionData, s: SolutionData, input : InputData, min : real, row : int)
    decreases s.k - ps.k
    requires input.Valid()
    requires 0 < |input.times|
    requires 0 <= row < |input.times|
    requires input.IsMin(min, row)
    requires |ps.employeesAssign| == |s.employeesAssign|
    requires ps.Partial(input)
    requires|s.employeesAssign| == |ps.employeesAssign|
            && s.k == |s.employeesAssign|
            && row <= ps.k <= s.k
            && s.Extends(ps)
            && s.Valid(input)
    ensures s.TotalTime(input.times) >= ps.TotalTime(input.times) + ((|ps.employeesAssign| - ps.k) as real) * min
  {

    if (ps.k == s.k) {
      assert s.Equals(ps);
      s.EqualTimeFromEquals(ps,input);
      assert s.TotalTime(input.times) == ps.TotalTime(input.times);
    }
    else {
      var ps' := SolutionData(ps.employeesAssign[ps.k := s.employeesAssign[ps.k]], ps.k + 1);
      AddTimeMaintainsSumConsistency(ps,ps',input);

      assert ps'.TotalTime(input.times) >= ps.TotalTime(input.times) + min by{
        assert ps'.TotalTime(input.times) == ps.TotalTime(input.times) + input.times[ps.k][s.employeesAssign[ps.k]];

        assert input.times[ps.k][s.employeesAssign[ps.k]] >= min by {
          assert input.IsMin(min,row);
          assert 0 <= s.employeesAssign[ps.k] < |input.times[ps.k]|;
        }
      }

      AddTimesLowerBound(ps', s, input, min, row);

      assert s.TotalTime(input.times) >= ps'.TotalTime(input.times) + ((|ps'.employeesAssign| - ps'.k) as real) * min;
      assert |ps'.employeesAssign| == |ps.employeesAssign|;
      assert ps'.k == ps.k + 1;
      asrealEqual(ps'.k,  ps.k + 1, |ps'.employeesAssign|,|ps.employeesAssign|);
      assert ((|ps'.employeesAssign| - ps'.k) as real) == ((|ps.employeesAssign| - (ps.k + 1)) as real);
      assert ((|ps'.employeesAssign| - ps'.k) as real) == ((|ps.employeesAssign| - ps.k - 1) as real);
      assert s.TotalTime(input.times) >= ps'.TotalTime(input.times) + ((|ps.employeesAssign| - (ps.k + 1)) as real) * min;

      calc {
        s.TotalTime(input.times);
      >=
        (ps.TotalTime(input.times) + min) + ((|ps.employeesAssign| - ps.k - 1 ) as real) * min;
        {associativity(ps.TotalTime(input.times),min,((|ps.employeesAssign| - ps.k - 1 ) as real) * min);}
        ps.TotalTime(input.times) + (min + (((|ps.employeesAssign| - ps.k) - 1 ) as real) * min);
      }
      asrealMultApp(ps,input,min);
    }
  }

  static lemma  associativity(a:real,b:real,c:real)
    ensures (a + b) + c == a + (b + c)
  {}

  static  lemma asrealPlusOne(a:int)
    ensures  (a + 1) as real == (a as real) + (1 as real)
  {}

  static  lemma asrealMult(y:real, a:int, x:real)
    ensures  y + (x + ((a - 1) as real) * x) == y + (a as real) * x
  {}

  static lemma asrealMultApp(ps : SolutionData, input : InputData, min : real)
    requires input.Valid()
    requires ps.Partial(input)
    ensures ps.TotalTime(input.times) + (min + (((|ps.employeesAssign| - ps.k) - 1 ) as real) * min) ==
            ps.TotalTime(input.times) + ((|ps.employeesAssign| - ps.k) as real) * min
  {
    asrealMult(ps.TotalTime(input.times),|ps.employeesAssign| - ps.k,min);
  }

  static lemma asrealEqual(a:int,b:int,c:int,d:int)
    requires a == b && c == d
    ensures (c - a) as real == (d - b) as real
  {}





  /*
  Lema: si dos soluciones (this y s) son idénticas (igualdad de campos), entonces tienen la misma sumas de tiempos. 
  Esto es por que el contenido de employeesAssign de cada solución es igual y el cálculo acumulativo de tiempos
  serán idéntico.
  //
  Propósito: demostrar el lema AddTimeMaintainsSumConsistency.
  //
  Verificación: mediante inducción en this y s.
  */
  lemma EqualTimeFromEquals(s : SolutionData, input : InputData)
    decreases k
    requires input.Valid()
    requires this.Explicit(input.times)
    requires |input.times| == |this.employeesAssign| == |s.employeesAssign|
    requires this.k <= |this.employeesAssign|
    requires s.k <= |s.employeesAssign|
    requires this.Equals(s)
    ensures this.TotalTime(input.times) == s.TotalTime(input.times)
  {
    if k == 0 {

    }
    else {
      SolutionData(employeesAssign, k - 1).EqualTimeFromEquals(SolutionData(s.employeesAssign, s.k - 1), input);
    }
  }

  /* 
  Lema: dadas dos soluciones parciales ps1 y ps2 que son idénticas (igualdad de campos) y 
  sabiendo que bs es una extension óptima de ps1, entonces bs también es extensión optima de ps2.
  //
  Propósito: verificar que bs es la extensión óptima de ps al salir de la rama t-esima en EmployeesBT de BT.dfy.
  //
  Demostración: mediante el lema EqualTimeFromEquals.
  */
  lemma EqualsOptimalExtensionFromEquals(ps1 : SolutionData, ps2: SolutionData, input : InputData)
    requires input.Valid()
    requires this.Valid(input)
    requires |ps1.employeesAssign| == |ps2.employeesAssign|
    requires ps1.k <= |ps1.employeesAssign|
    requires ps2.k <= |ps2.employeesAssign|
    requires ps1.Equals(ps2)
    requires this.OptimalExtension(ps1, input)
    ensures this.OptimalExtension(ps2, input)
  {

    assert ps1.k == ps2.k && forall i | 0 <= i < ps1.k :: ps1.employeesAssign[i] == ps2.employeesAssign[i]; //def clave de Equals

    assert this.OptimalExtension(ps2, input) by {
      assert ps2.Partial(input) by {
        ps1.EqualTimeFromEquals(ps2, input);
      }
      assert this.Extends(ps2);
      assert forall s : SolutionData | s.Valid(input) && s.Extends(ps2) :: s.TotalTime(input.times) >= this.TotalTime(input.times);
    }
  }

  /* 
  Lema: sea una solución s que extiende a this, entonces el tiempo total de s debe ser al menos el tiempo total 
  de ps. Esto es por que el contenido de employeesAssign de cada solución es igual hasta this.k.
  //
  Propósito: demostrar el lema InvalidExtensionsFromInvalidPs de BT.dfy.
  //
  Demostración: mediante inducción en s, esta se va reduciendo hasta this.k.
  */
  lemma GreaterOrEqualTimeFromExtends(s: SolutionData, input: InputData)
    decreases s.k
    requires input.Valid()
    requires |this.employeesAssign| == |s.employeesAssign| == |input.times|
    requires this.k <= |this.employeesAssign|
    requires s.k <= |s.employeesAssign|
    requires this.k <= s.k
    requires this.Explicit(input.times)
    requires s.Extends(this)
    requires s.Explicit(input.times)
    ensures s.TotalTime(input.times) >= this.TotalTime(input.times)
  {
    if this.k == s.k {
      this.EqualTimeFromEquals(s, input);
    }
    else {
      ghost var s := SolutionData(s.employeesAssign, s.k-1);
      this.GreaterOrEqualTimeFromExtends(s, input);
    }
  }
}