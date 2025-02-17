-- ****************************************************************************************--
--                             SUMATIVA 3: LILIANA TAPIA                                   --
-- ****************************************************************************************--

-----------------------------------------------------
-- ESPECIFICACIÓN DEL PACKAGE 
-----------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_liquidacion AS
    -- Variable global para almacenar el promedio de ventas
    v_promedio_ventas NUMBER;
    
    -- Procedimiento para registrar errores en ERROR_CALC
    PROCEDURE registrar_error(
        p_subprograma   VARCHAR2, -- Nombre del subprograma o función donde se produjo el error.
        p_mensaje       VARCHAR2, -- Mensaje que describe el error (ej. ORA-01403, ORA-01422, etc.)
        p_descripcion   VARCHAR2  -- Descripción detallada del programador.
    );
    
    -- Función para calcular y retornar el promedio de ventas del año anterior.
    FUNCTION calcular_promedio_ventas RETURN NUMBER;
END pkg_liquidacion;
/
-----------------------------------------------------
-- CUERPO DEL PACKAGE
-----------------------------------------------------
CREATE OR REPLACE PACKAGE BODY pkg_liquidacion AS

    ------------------------------------------------------------------------------
    -- Procedimiento para registrar errores en la tabla ERROR_CALC
    -- con transacción autónoma, para que se guarden aun si hay ROLLBACK 
    ------------------------------------------------------------------------------
    PROCEDURE registrar_error(
        p_subprograma   VARCHAR2,
        p_mensaje       VARCHAR2,
        p_descripcion   VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION; 
    BEGIN
        INSERT INTO ERROR_CALC (
            CORREL_ERROR,
            RUTINA_ERROR,
            DESCRIP_ERROR,
            DESCRIP_USER
        ) VALUES (
            SEQ_ERROR.NEXTVAL,
            p_subprograma,
            p_mensaje,
            p_descripcion
        );
        COMMIT;  -- Confirma de inmediato para no perder el registro.
    EXCEPTION
        WHEN OTHERS THEN
            -- Evita que el proceso principal falle por no poder registrar el error.
            NULL;
    END registrar_error;
    
    ------------------------------------------------------------------------------
    -- Función para calcular el promedio de ventas del año anterior.
    ------------------------------------------------------------------------------
   FUNCTION calcular_promedio_ventas RETURN NUMBER IS
        v_suma_ventas NUMBER;
        v_num_boletas NUMBER;
        v_promedio    NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Calculando promedio de ventas del año anterior...');

        -- Calcular la suma total de ventas del año anterior
        SELECT SUM(d.VALOR_TOTAL)
          INTO v_suma_ventas
          FROM DETALLE_BOLETA d
          JOIN BOLETA b 
            ON d.NRO_BOLETA = b.NRO_BOLETA
         WHERE EXTRACT(YEAR FROM b.FECHA) = EXTRACT(YEAR FROM SYSDATE) - 1;

        -- Calcular el número de boletas registradas en el año anterior.
        SELECT COUNT(DISTINCT b.NRO_BOLETA)
          INTO v_num_boletas
          FROM BOLETA b
         WHERE EXTRACT(YEAR FROM b.FECHA) = EXTRACT(YEAR FROM SYSDATE) - 1;

        -- Si se registraron boletas, calcular el promedio; de lo contrario, 0.
        IF v_num_boletas > 0 THEN
            v_promedio := ROUND(v_suma_ventas / v_num_boletas);
        ELSE
            v_promedio := 0;
        END IF;

        DBMS_OUTPUT.PUT_LINE('Suma de ventas: ' || v_suma_ventas);
        DBMS_OUTPUT.PUT_LINE('Número de boletas: ' || v_num_boletas);
        DBMS_OUTPUT.PUT_LINE('Promedio de ventas calculado: ' || v_promedio);

        RETURN v_promedio;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            pkg_liquidacion.registrar_error(
                'FN CALCULAR_PROMEDIO_VENTAS',
                'ORA-01403: No se ha encontrado ningún dato',
                'Error al calcular promedio de ventas'
            );
            DBMS_OUTPUT.PUT_LINE('Error en calcular_promedio_ventas: ' || SQLERRM);
            RETURN 0;
        WHEN TOO_MANY_ROWS THEN
            pkg_liquidacion.registrar_error(
                'FN CALCULAR_PROMEDIO_VENTAS',
                'ORA-01422: la recuperación exacta devuelve un número mayor de filas que el solicitado',
                'Error al calcular promedio de ventas'
            );
            DBMS_OUTPUT.PUT_LINE('Error en calcular_promedio_ventas: ' || SQLERRM);
            RETURN 0;
        WHEN OTHERS THEN
            pkg_liquidacion.registrar_error(
                'FN CALCULAR_PROMEDIO_VENTAS',
                SQLERRM,
                'Error desconocido al calcular promedio de ventas'
            );
            DBMS_OUTPUT.PUT_LINE('Error en calcular_promedio_ventas: ' || SQLERRM);
            RETURN 0;
    END calcular_promedio_ventas;

END pkg_liquidacion;
/
---------------------------------------------------------------------------------
-- FUNCION PARA OBTENER PORCENTAJE POR ANTIGÜEDAD BASADO EN LOS AÑOS DE SERVICIOS
---------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION obtener_pct_antiguedad(
    p_anios NUMBER -- Años de servicio del empleado.
) RETURN NUMBER IS -- Retorna: Porcentaje de asignación por antigüedad o 0 en caso de error.
    v_pct NUMBER;
BEGIN
    
    SELECT PORC_ANTIGUEDAD
      INTO v_pct
      FROM PCT_ANTIGUEDAD
     WHERE p_anios BETWEEN ANNOS_ANTIGUEDAD_INF AND ANNOS_ANTIGUEDAD_SUP;
    
    DBMS_OUTPUT.PUT_LINE('Porcentaje antigüedad para ' || p_anios || ' años: ' || NVL(v_pct, 0));
    RETURN NVL(v_pct, 0);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        pkg_liquidacion.registrar_error(
            'FN PCT ESPECIAL',
            'ORA-01403: No se ha encontrado ningún dato.',
            'Error al calcular PCT ESPECIAL '
        );
        RETURN 0;
    WHEN TOO_MANY_ROWS THEN
        pkg_liquidacion.registrar_error(
            'FN PCT ESPECIAL',
            'ORA-01422: la recuperación exacta devuelve un número mayor de filas que el solicitado',
            'Error al calcular PCT ESPECIAL' 
        );
        RETURN 0;
    WHEN OTHERS THEN
        pkg_liquidacion.registrar_error(
            'FN PCT ESPECIAL',
            SQLERRM,
            'Error desconocido en FN PCT ESPECIAL.'
        );
        RETURN 0;
END obtener_pct_antiguedad;
/
----------------------------------------------------------------------------------
-- FUNCION PARA OBTENER PORCENTAJE POR ESTUDIOS BASADO EN EL CÓDIGO DE ESCOLARIDAD
----------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION obtener_pct_estudios(
    p_cod_estudio NUMBER -- Código de escolaridad del empleado.
) RETURN NUMBER IS -- Retorna: Porcentaje de asignación por estudios (o 0 en caso de error).
    v_pct NUMBER;
BEGIN
    SELECT PORC_ESCOLARIDAD
      INTO v_pct
      FROM PCT_NIVEL_ESTUDIOS
     WHERE COD_ESCOLARIDAD = p_cod_estudio;

    DBMS_OUTPUT.PUT_LINE('Porcentaje estudios para código ' || p_cod_estudio || ': ' || NVL(v_pct, 0));
    RETURN NVL(v_pct, 0);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        pkg_liquidacion.registrar_error(
            'FN ESTUDIOS',
            'ORA-01403:  No se ha encontrado ningún dato.',
            'Error al calcular nivel de estudios empleado '
        );
        RETURN 0;
    WHEN TOO_MANY_ROWS THEN
        pkg_liquidacion.registrar_error(
            'FN ESTUDIOS',
            'ORA-01422: la recuperación exacta devuelve un número mayor de filas que el solicitado',
            'Error al calcular nivel de estudios empleado ' 
        );
        RETURN 0;
    WHEN OTHERS THEN
        pkg_liquidacion.registrar_error(
            'FN ESTUDIOS',
            SQLERRM,
            'Error desconocido en FN ESTUDIOS.'
        );
        RETURN 0;
END obtener_pct_estudios;
/
---------------------------------------
-- PROCEDIMIENTO ALMACENADO PRINCIPAL 
---------------------------------------
CREATE OR REPLACE PROCEDURE calcular_liquidaciones(
    p_anio NUMBER,
    p_mes  NUMBER
) IS
BEGIN
    DBMS_OUTPUT.PUT_LINE('Iniciando cálculo de liquidaciones para año: ' || p_anio || ', mes: ' || p_mes);
    
    -- 1) Calcular y almacenar en la variable global el promedio de ventas del año anterior.
    pkg_liquidacion.v_promedio_ventas := pkg_liquidacion.calcular_promedio_ventas;
    DBMS_OUTPUT.PUT_LINE('Promedio de ventas del año anterior: ' || pkg_liquidacion.v_promedio_ventas);
    
    -- 2) Procesar todos los empleados registrados en la tabla EMPLEADO.
    FOR v_empleado IN (
        SELECT *
          FROM EMPLEADO
    ) LOOP
        DECLARE
            v_ventas          NUMBER := 0;
            v_pct_antiguedad  NUMBER := 0;
            v_pct_estudios    NUMBER := 0;
            v_asig_antiguedad NUMBER := 0;
            v_asig_estudios   NUMBER := 0;
            v_total_haberes   NUMBER := 0;
            v_anios_servicio  NUMBER := 0;
        BEGIN
            DBMS_OUTPUT.PUT_LINE('-------------------------------------------');
            DBMS_OUTPUT.PUT_LINE('Procesando empleado: ' || v_empleado.RUN_EMPLEADO);
            
            -- A) Calcular años de servicio.
            v_anios_servicio := EXTRACT(YEAR FROM TO_DATE('2024-01-01', 'YYYY-MM-DD')) 
                                - EXTRACT(YEAR FROM v_empleado.FECHA_CONTRATO);
            DBMS_OUTPUT.PUT_LINE('Años de servicio: ' || v_anios_servicio);
            
            -- B) Calcular las ventas anuales del empleado para el año (p_anio - 1).
            SELECT ROUND(NVL(SUM(d.VALOR_TOTAL), 0))
              INTO v_ventas
              FROM DETALLE_BOLETA d
              JOIN BOLETA b ON d.NRO_BOLETA = b.NRO_BOLETA
             WHERE b.RUN_EMPLEADO = v_empleado.RUN_EMPLEADO
               AND EXTRACT(YEAR FROM b.FECHA) = p_anio - 1;
            DBMS_OUTPUT.PUT_LINE('Ventas del año anterior: ' || v_ventas);
            
            -- C) Si el 17% de las ventas del empleado supera el promedio, se asigna porcentaje antigüedad.
            IF (v_ventas * 0.17) > pkg_liquidacion.v_promedio_ventas THEN
                v_pct_antiguedad := obtener_pct_antiguedad(v_anios_servicio);
            ELSE
                v_pct_antiguedad := 0;
                DBMS_OUTPUT.PUT_LINE('El 17% de las ventas no supera el promedio, no se asigna antigüedad.');
            END IF;
            
            -- D) Obtener el porcentaje de asignación por estudios.
            v_pct_estudios := obtener_pct_estudios(v_empleado.COD_ESCOLARIDAD);
            
            DBMS_OUTPUT.PUT_LINE('Pct Antiguedad: ' || v_pct_antiguedad);
            DBMS_OUTPUT.PUT_LINE('Pct Estudios: ' || v_pct_estudios);
            
            -- E) Calcular la asignación especial por antigüedad.
            v_asig_antiguedad := ROUND(v_empleado.SUELDO_BASE * v_pct_antiguedad / 100);
            DBMS_OUTPUT.PUT_LINE('Asignación por antigüedad: ' || v_asig_antiguedad);
            
            -- F) Asignación por estudios (solo si el empleado tiene FONASA).
            IF v_empleado.COD_SALUD = 1 THEN
                v_asig_estudios := ROUND(v_empleado.SUELDO_BASE * v_pct_estudios / 100);
                DBMS_OUTPUT.PUT_LINE('Asignación por estudios: ' || v_asig_estudios);
            ELSE
                v_asig_estudios := 0;
                DBMS_OUTPUT.PUT_LINE('Empleado no tiene FONASA, no se asigna estudios.');
            END IF;
            
            -- G) Calcular el total de haberes.
            v_total_haberes := v_empleado.SUELDO_BASE + v_asig_antiguedad + v_asig_estudios;
            DBMS_OUTPUT.PUT_LINE('Sueldo Base: ' || v_empleado.SUELDO_BASE);
            DBMS_OUTPUT.PUT_LINE('Asig Especial: ' || v_asig_antiguedad);
            DBMS_OUTPUT.PUT_LINE('Asig Estudios: ' || v_asig_estudios);
            DBMS_OUTPUT.PUT_LINE('Total Haberes: ' || v_total_haberes);
            
            -- H) Insertar o actualizar (MERGE) en LIQUIDACION_EMPLEADO.
            MERGE INTO LIQUIDACION_EMPLEADO le
            USING (
                SELECT p_mes AS MES,
                       p_anio AS ANNO,
                       v_empleado.RUN_EMPLEADO AS RUN_EMPLEADO,
                       v_empleado.NOMBRE || ' ' || v_empleado.PATERNO || ' ' || v_empleado.MATERNO AS NOMBRE_EMPLEADO,
                       v_empleado.SUELDO_BASE AS SUELDO_BASE,
                       v_asig_antiguedad AS ASIG_ESPECIAL,
                       v_asig_estudios AS ASIG_ESTUDIOS,
                       v_total_haberes AS TOTAL_HABERES
                  FROM DUAL
            ) tmp
            ON (    le.MES          = tmp.MES
                AND le.ANNO         = tmp.ANNO
                AND le.RUN_EMPLEADO = tmp.RUN_EMPLEADO
            )
            WHEN MATCHED THEN
              UPDATE
                 SET le.NOMBRE_EMPLEADO = tmp.NOMBRE_EMPLEADO,
                     le.SUELDO_BASE     = tmp.SUELDO_BASE,
                     le.ASIG_ESPECIAL   = tmp.ASIG_ESPECIAL,
                     le.ASIG_ESTUDIOS   = tmp.ASIG_ESTUDIOS,
                     le.TOTAL_HABERES   = tmp.TOTAL_HABERES
            WHEN NOT MATCHED THEN
              INSERT (
                MES, ANNO, RUN_EMPLEADO, NOMBRE_EMPLEADO,
                SUELDO_BASE, ASIG_ESPECIAL, ASIG_ESTUDIOS, TOTAL_HABERES
              )
              VALUES (
                tmp.MES, tmp.ANNO, tmp.RUN_EMPLEADO, tmp.NOMBRE_EMPLEADO,
                tmp.SUELDO_BASE, tmp.ASIG_ESPECIAL, tmp.ASIG_ESTUDIOS, tmp.TOTAL_HABERES
              );
            
            DBMS_OUTPUT.PUT_LINE('Liquidación insertada/actualizada para: ' || v_empleado.RUN_EMPLEADO);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_liquidacion.registrar_error(
                    'PR CALCULAR_LIQUIDACIONES',
                    'ORA-01403: No se ha encontrado ningún dato.',
                    'Error procesando empleado  ' || v_empleado.RUN_EMPLEADO
                );
                DBMS_OUTPUT.PUT_LINE('Error procesando empleado ' || v_empleado.RUN_EMPLEADO || ': ' || SQLERRM);
            WHEN TOO_MANY_ROWS THEN
                pkg_liquidacion.registrar_error(
                    'PR CALCULAR_LIQUIDACIONES',
                    'ORA-01422: la recuperación exacta devuelve un número mayor de filas que el solicitado',
                    'Error procesando empleado ' || v_empleado.RUN_EMPLEADO
                );
                DBMS_OUTPUT.PUT_LINE('Error procesando empleado ' || v_empleado.RUN_EMPLEADO || ': ' || SQLERRM);
            WHEN OTHERS THEN
                pkg_liquidacion.registrar_error(
                    'PR CALCULAR_LIQUIDACIONES',
                    SQLERRM,
                    'Error procesando empleado ' || v_empleado.RUN_EMPLEADO
                );
                DBMS_OUTPUT.PUT_LINE('Error procesando empleado ' || v_empleado.RUN_EMPLEADO || ': ' || SQLERRM);
        END;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('Proceso de cálculo de liquidaciones finalizado.');
END calcular_liquidaciones;
/
-----------------------------------------------------
-- Ejecutar procedimiento para junio 2024
-----------------------------------------------------
BEGIN
  calcular_liquidaciones(2024, 6);
END;
/
--------------------------------------------------------
-- TRIGGER 1: Impedir INSERT o DELETE de productos L-V
--------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_productos_no_ins_del
BEFORE INSERT OR DELETE
ON PRODUCTO
FOR EACH ROW
BEGIN
    -- Verificar si hoy es Lunes-Viernes
    IF TO_CHAR(SYSDATE, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') IN ('MON','TUE','WED','THU','FRI') THEN
        IF INSERTING THEN
            RAISE_APPLICATION_ERROR(-20501, 'TABLA DE PRODUCTO PROTEGIDA');
        ELSIF DELETING THEN
            RAISE_APPLICATION_ERROR(-20500, 'No se pueden eliminar productos de lunes a viernes.');
        END IF;
    END IF;
END;
/
-------------------------------------------------------------------------------
-- TRIGGER 2: Recalcular DETALLE_BOLETA si VALOR_UNITARIO > 110% del promedio
-------------------------------------------------------------------------------
SET SERVEROUTPUT ON;
CREATE OR REPLACE TRIGGER trg_productos_update_unitario
BEFORE UPDATE OF VALOR_UNITARIO
ON PRODUCTO
FOR EACH ROW
DECLARE
    v_promedio NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Trigger se ejecutó');  
    
    -- Obtener el promedio de ventas del año anterior utilizando la función del package. 
    v_promedio := pkg_liquidacion.calcular_promedio_ventas;
    DBMS_OUTPUT.PUT_LINE('Valor promedio: ' || v_promedio);
    -- Si el nuevo valor unitario supera el 110% del promedio, actualizar el valor total en DETALLE_BOLETA.
    IF :NEW.VALOR_UNITARIO > (v_promedio * 1.1) THEN
        UPDATE DETALLE_BOLETA
           SET VALOR_TOTAL = CANTIDAD * :NEW.VALOR_UNITARIO
         WHERE COD_PRODUCTO = :NEW.COD_PRODUCTO;
         
        DBMS_OUTPUT.PUT_LINE('Filas actualizadas en DETALLE_BOLETA: ' || SQL%ROWCOUNT);
    END IF;
END;
/
-- ********************************************
-- Para visualizar tabla LIQUIDACION_EMPLEADO
-- ********************************************

SELECT 
    le.MES,
    le.ANNO,
    le.RUN_EMPLEADO,
    le.NOMBRE_EMPLEADO,
    le.SUELDO_BASE,
    le.ASIG_ESPECIAL,
    le.ASIG_ESTUDIOS,
    le.TOTAL_HABERES
FROM LIQUIDACION_EMPLEADO le
JOIN EMPLEADO e ON le.RUN_EMPLEADO = e.RUN_EMPLEADO
WHERE e.TIPO_EMPLEADO = 5 -- Filtra solo vendedores 
ORDER BY le.ANNO, le.MES, le.RUN_EMPLEADO;

-- *******************************************************************************
-- a) Test 1: Simular que un día lunes se agrega o elimina un producto cualquiera.
-- *******************************************************************************
--  Insertar un producto 
INSERT INTO PRODUCTO (COD_PRODUCTO, DESCRIPCION, VALOR_UNITARIO)
VALUES (33, 'PRODUCTO TEST LUNES', 1000);

-- Eliminar un producto 
DELETE FROM PRODUCTO
 WHERE COD_PRODUCTO = 1;   
-- *******************************************************************************
-- b) Test 2: Actualizar el valor unitario del producto 19 y asignarle 1000 pesos.
-- ******************************************************************************* 
 UPDATE PRODUCTO
   SET VALOR_UNITARIO = 1000
 WHERE COD_PRODUCTO = 19;

-- ******************************************************************************* 
-- c) Test 3: Actualizar el valor unitario del producto 19 y asignarle 10000 pesos. 
-- ******************************************************************************* 
 UPDATE PRODUCTO
   SET VALOR_UNITARIO = 10000
 WHERE COD_PRODUCTO = 19;
 
 


 
 
 
