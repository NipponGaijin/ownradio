CREATE OR REPLACE FUNCTION public.detachdevicefromuser(
	device_id text,
	googleemail text,
	googleidtoken text,
	OUT userid uuid,
	OUT success boolean,
	OUT request_info text)
    RETURNS record
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$
	DECLARE 
		deviceid UUID := NULL;
		useruuid UUID := NULL;
	BEGIN
		
-- 		Проверка существует ли полученный device_id в БД
		SELECT
			public.devices.recid
		INTO deviceid
		FROM public.devices
		WHERE public.devices.recid = CAST(device_id AS UUID);
-- 			Если устройство найдено в БД, проверяем найден ли пользователь с email
		IF deviceid IS NOT NULL THEN
			-- 	Получение id пользователя с emailom
			SELECT 
				users.recid
			INTO useruuid
			FROM public.users
			WHERE public.users.email = googleemail;
-- 			Если пользователь с таким e-mailom найден, устанавливаем его id для устройства
			IF useruuid IS NOT NULL THEN
				UPDATE public.devices SET userid = useruuid WHERE recid = deviceid;
				userid := useruuid;
				success := True;
			ELSE
-- 			Иначе назначаем email и idtoken пользователю, созданному этим устройством
				UPDATE public.users SET email = googleemail, idtoken = googleidtoken WHERE public.users.recid = deviceid;
				userid := useruuid;
				success := True;
			END IF;
		ELSE
			success := False;
			request_info := 'Device not found';
		END IF;
		

	END
$BODY$;

ALTER FUNCTION public.detachdevicefromuser(text, text, text)
    OWNER TO postgres;
