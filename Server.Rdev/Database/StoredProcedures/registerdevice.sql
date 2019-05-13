CREATE OR REPLACE FUNCTION public.registerdevice(i_deviceid uuid, i_devicename character varying)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
BEGIN
	-- Функция регистрации нового устройства

	-- Добавляем устройство, если его еще не существует
	-- Если ID устройства еще нет в БД
	IF NOT EXISTS(SELECT recid
				  FROM devices
				  WHERE recid = i_deviceid)
	THEN

		-- Добавляем нового пользователя
		INSERT INTO users (recid, recname, reccreated) SELECT
						   i_deviceid,
						   i_devicename,
						   now()
					   WHERE NOT EXISTS(SELECT recid FROM users WHERE recid = i_deviceid)
		ON CONFLICT (recid) DO NOTHING;

		-- Добавляем новое устройство
		INSERT INTO devices (recid, userid, recname, reccreated) SELECT
						 i_deviceid,
						 i_deviceid,
						 i_devicename,
						 now()
		ON CONFLICT (recid) DO NOTHING;
	END IF;
	RETURN TRUE;
END;
$function$
;
