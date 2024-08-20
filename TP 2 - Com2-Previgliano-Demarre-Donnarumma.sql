-- Trabajo Practico 2 - Base de datos

-----------------------------------------------------------------------------------------------------

-- CONSIGNA 3. Suponga que se desea verificar mensualmente si los planes de cada uno de los usuarios estan
-- al dia con los pagos y, en funcion de eso, actualizar el plan como activo o inactivo. Cree el
-- procedimiento almacenado correspondiente, y proponga los criterios a tener en cuenta para
-- pasar un plan de activo a inactivo.

----------------------------------------------------------------------------------------------------
-- Primero vamos a crear (solo con las tablas del TP2) nuestra base de datos de acuerdo
-- al nuevo diagrama entidad-relacion y vamos a ingresar algunos registros como para poder cumplir con la 
-- consigna.
----------------------------------------------------------------------------------------------------

CREATE DATABASE cinema_paraiso_streaming;
USE cinema_paraiso_streaming;

CREATE TABLE tipo_suscripcion (
	id int IDENTITY(1,1) PRIMARY KEY,
	tipo varchar(20) UNIQUE NOT NULL
);

CREATE TABLE planes (
	id int IDENTITY(1,1) PRIMARY KEY,
	nombre varchar(20) UNIQUE NOT NULL
);

CREATE TABLE usuario (
	usuario varchar(40) PRIMARY KEY,
	contraseña varchar(40) NOT NULL
);

CREATE TABLE registros (
	id_usuario varchar(40),
	id_plan int,
	id_suscripcion int,
	fecha_pago date NULL,
	activo bit NOT NULL,
	PRIMARY KEY (id_usuario, id_plan, id_suscripcion),
	CONSTRAINT FK_registros_usuario FOREIGN KEY (id_usuario) 
	REFERENCES usuario(usuario),
	CONSTRAINT FK_registros_planes FOREIGN KEY (id_plan) 
	REFERENCES planes(id),
	CONSTRAINT FK_registros_suscripcion FOREIGN KEY (id_suscripcion) 
	REFERENCES tipo_suscripcion(id)
);

CREATE TABLE pelicula(
  id int IDENTITY(1,1) PRIMARY KEY,
  nombre varchar(80) NOT NULL,
  atp bit NOT NULL,
  subtitulos bit NOT NULL,
  genero varchar(20) NOT NULL,
  );

CREATE TABLE pelicula_streaming(
  id_pelicula int FOREIGN KEY REFERENCES pelicula(id),
  id_plan int FOREIGN KEY REFERENCES planes(id)
  PRIMARY KEY(id_pelicula, id_plan),
  );

INSERT INTO planes VALUES ('Gratuito');
INSERT INTO planes VALUES ('Premium');
INSERT INTO planes VALUES ('Familiar');

INSERT INTO tipo_suscripcion VALUES ('Mensual');
INSERT INTO tipo_suscripcion VALUES ('Anual');


INSERT INTO usuario VALUES ('usuario1', '1234');
INSERT INTO usuario VALUES ('usuario2', '5678');
INSERT INTO usuario VALUES ('usuario3', '9123');
INSERT INTO usuario VALUES ('usuario4', '9123');
INSERT INTO usuario VALUES ('usuario5', '4253');
INSERT INTO usuario VALUES ('usuario6', '3235');
INSERT INTO usuario VALUES ('usuario7', '6523');
INSERT INTO usuario VALUES ('usuario8', '5423');
INSERT INTO usuario VALUES ('usuario9', '8790');

INSERT INTO registros VALUES ('usuario1', 1, 1, NULL, 1);
INSERT INTO registros VALUES ('usuario2', 2, 1, '2022-08-29', 1); -- 0
INSERT INTO registros VALUES ('usuario3', 2, 1, '2022-11-14', 1); 
INSERT INTO registros VALUES ('usuario4', 3, 1, '2022-10-30', 1); -- 0
INSERT INTO registros VALUES ('usuario5', 3, 2, '2022-02-01', 1); 
INSERT INTO registros VALUES ('usuario6', 1, 1, NULL, 1);
INSERT INTO registros VALUES ('usuario7', 1, 1, NULL, 1);
INSERT INTO registros VALUES ('usuario8', 3, 2, '2021-11-01', 1); -- 0
INSERT INTO registros VALUES ('usuario9', 3, 2, '2020-03-04', 1); -- 0

----------------------------------------------------------------------------------------------------

-- Los criterios a tener en cuenta para pasar un plan de activo a inactivo son los siguiente: 
--
-- - Solo vamos a trabajar con los registros cuyo plan no sea el gratuito. Consideramos que si el plan es el 
--   gratuito la fecha de pago (que es la fecha del ultimo pago) se pone en NULL y que no hay pago que 
--   verificar en ese caso.
--
-- - Del resto de los planes: en caso de ser mensual se evaluara si pasaron 30 o mas del dia que pago y en
--   caso de ser anual se evaluara si pasaron 12 meses o mas para desactivar la cuenta.
--
----------------------------------------------------------------------------------------------------
-- Fue dividido en 2 procedimientos almacenados para mejorar la lectura del mismo. El primero
-- desactiva registros individuales en caso de que se cumplan las condiciones necesarias. Y el segundo
-- recorre la totalidad  de los registros que no sean cuentas gratuitas (ya que estas no habria que
-- verificarlas) y tomando una por una (a traves de un bucle while) va llamando al anterior procedimiento 
-- almacenado para cumplir con la consigna
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
-- 1- CREACION DEL PRIMER SP
-- El siguiente procedimiento almacenado cambia el valor de activo a inactivo de una sola cuenta. Recibe
-- como parametros de entrada la PK del registro que queremos comprobar, con esos datos busca la fecha
-- de pago para luego (dependiendo de si su tipo de plan es mensual o anual) evaluar si paso el tiempo 
-- correspondiente y pasar de activo a inactivo a un registro.
-----------------------------------------------------------------------------------------------------
GO

CREATE PROCEDURE usp_desactivacion_registro -- nombre del procedimiento almacenado
	@id_usuario varchar(40), -- parametros de entrada: clave primaria de la tupla para identificarla correctamente
	@id_plan int,
	@id_suscripcion int
AS

DECLARE @fecha_pago date -- en esta variable guardaremos la fecha de pago

SELECT @fecha_pago = fecha_pago
FROM registros
WHERE id_usuario = @id_usuario AND id_plan = @id_plan AND id_suscripcion = @id_suscripcion

IF (@id_suscripcion = 1) -- si la suscripcion es mensual
	IF ( SELECT DATEDIFF(DAY, @fecha_pago, GETDATE()) ) >= 30 -- si la diferencia de dias entre el ultimo dia que pago y el momento actual es mayor de 30
		UPDATE registros -- seteamos en la tupla correspondiente activo = 0
		SET activo = 0 
		WHERE id_usuario = @id_usuario AND id_plan = @id_plan AND id_suscripcion = @id_suscripcion

IF (@id_suscripcion = 2) -- si la suscripcion es anual
	IF ( SELECT DATEDIFF(MONTH, @fecha_pago, GETDATE()) ) >= 12 -- si la diferencia de meses entre el ultimo mes que pago y el mes actual es mayor de 12
		UPDATE registros -- seteamos en la tupla correspondiente activo = 0
		SET activo = 0 
		WHERE id_usuario = @id_usuario AND id_plan = @id_plan AND id_suscripcion = @id_suscripcion

GO
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
-- 2- CREACION DEL SEGUNDO SP
-- Este procedimiento almacenado lo que hace es ir recorriendo cada una de las filas que no sean registros
-- de plan gratuito y va tomando los valores de las PK una por una en un bucle WHILE y pasandoselas al anterior
-- procedimiento para que el mismo cambie los valores en caso de ser necesario
----------------------------------------------------------------------------------------------------
GO
CREATE PROCEDURE usp_verificacion_mensual -- creacion de procedimiento almacenado
AS

DECLARE @registros_provisorios table( id_usuario varchar(40), id_plan int, id_suscripcion int ) 
-- la variable de arriba es de tipo tabla, son lo mismo que las tablas que creamos para los registros
-- con la diferencia que se crea al ejecutar la query y elimina al terminar la ejecucion

INSERT INTO @registros_provisorios SELECT id_usuario, id_plan, id_suscripcion FROM registros WHERE id_plan != 1
-- en la variable provisoria tipo tabla ingresamos los atributos id_usuario, id_plan, id_suscripcion
-- de las filas de la tabla registro donde el plan no sea gratuito. esta variable va a contener los 
-- registros que tenemos que pasarle al procedimiento almacenado que desactiva

DECLARE @contador int = (SELECT COUNT(*) FROM @registros_provisorios)
-- esta variable es un contador con el total de filas que tenemos que recorrer, nos sirve como
-- condicion del while, para que el mismo termine

WHILE @contador > 0 -- mientras haya registros aun en la variable tipo tabla creada se ejecuta
BEGIN
	
	DECLARE @id_usuario varchar(40) 
	DECLARE @id_plan int  
	DECLARE @id_suscripcion int
	-- en estas 3 variables vamos a guardar los datos de la PK de cada fila para pasarsela como parametro
	-- de entrada al procedimiento que nos desactiva cuentas

	SELECT TOP 1 @id_usuario = id_usuario, @id_plan = id_plan, @id_suscripcion = id_suscripcion FROM @registros_provisorios
	-- guardamos en nuestras variables los datos de la PK del primer registro. siempre de los registros
	-- que tenemos que comprobar vamos agarrando el de arriba.

	EXECUTE usp_desactivacion_registro @id_usuario, @id_plan, @id_suscripcion
	-- ejecutamos nuestro proceso de almacenamiento que desactiva

	DELETE FROM @registros_provisorios WHERE id_usuario = @id_usuario AND id_plan = @id_plan AND id_suscripcion = @id_suscripcion
	-- eliminamos el registro que recien acabamos de comprobar en el renglon de arriba para continuar con el
	-- de abajo en la proxima iteracion (si es que aun quedan registros)

	SET @contador = (SELECT COUNT(*) FROM @registros_provisorios)
	-- le seteamos a nuestro contador el valor correspondiente a la cantidad de registros que quedan 
	-- en la variable tipo tabla. si es != 0 seguiremos iterando, sino terminamos

END
GO
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
-- Seleccionar el siguiente bloque de 3 sentencias para: 1-ver el estado anterior de los registros, 2-
-- que se ejecute la verificacion, 3-tener el nuevo estado para corroborar los resultados
-----------------------------------------------------------------------------------------------------
GO
SELECT * FROM registros
EXEC usp_verificacion_mensual
SELECT * FROM registros
GO
----------------------------------------------------------------------------------------------------
-- Para volver los valores de los registros creados como ejemplo al estado anterior ejecutar la sentencia
-- de eliminacion de filas de abajo y volver a ejecutar la sentencia insert de mas arriba
-----------------------------------------------------------------------------------------------------
DELETE FROM registros WHERE id_usuario LIKE 'usua%'
-----------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------

-- CONSIGNA 4. Cree un procedimiento almacenado que reciba como parametros un usuario y una contraseña,
-- y devuelva 1 si el login es correcto (es decir, coincide usuario, contraseña, y el plan está activo)
-- y 0 en cualquier otro caso.

-----------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------
-- Recibe como entrada un usuario, una contraseña y devuelve un entero como salida.
-----------------------------------------------------------------------------------------------------
GO
CREATE PROCEDURE usp_login
	@usuario varchar(40), -- parametros de entrada 
	@contraseña varchar(40),
	@salida int OUTPUT -- parametro de salida
AS
	
	DECLARE @correcto int -- variable que guardara el resultado de si hay coincidencia

	-- esta consulta nos devuelve un conteo de la cantidad de registros donde un usuario y contraseña
	-- de la base de datos (dados de alta) coincidan con los usuarios y contraseña que pasamos.
	-- este resultado se guarda en la variable que declaramos arriba
	SELECT @correcto = COUNT(*)
	FROM registros AS reg, usuario AS usu, 
	(SELECT @usuario AS 'usuario', @contraseña AS 'contraseña', 1 AS 'activo') as entrada 
	WHERE reg.id_usuario = usu.usuario AND entrada.usuario = usu.usuario 
	AND entrada.contraseña = usu.contraseña AND entrada.activo = reg.activo

	
	IF (@correcto = 1) -- si hay una coincidencia
		SET @salida = 1 -- seteamos 1 a la variable de salida
	ELSE -- si no la hay 
		SET @salida = 0 -- seteamos 0 a la variable de salida

	RETURN @salida -- devolvemos la variable
GO
-----------------------------------------------------------------------------------------------------
-- Bloque de codigo de login:
-----------------------------------------------------------------------------------------------------
GO
DECLARE @salida int
EXECUTE usp_login 'usuario2', '5678', @salida OUTPUT -- el primer parametro es el usuario, el segundo la contraseña
SELECT @salida AS 'Resultado login (1-Correcto, 0-Incorrecto)'
GO
-----------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------
-- UTILIDADES: 
SELECT * FROM planes;
SELECT * FROM tipo_suscripcion;
SELECT * FROM usuario;
SELECT * FROM registros;
-----------------------------------------------------------------------------------------------------

