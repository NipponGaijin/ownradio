CREATE OR REPLACE FUNCTION public.track_insert(i_trackid uuid, i_localdevicepathupload character varying, i_path character varying, i_deviceid uuid, i_outerguid uuid, i_outersource character varying, i_artist character varying, i_recname character varying, i_length integer)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$ 	
DECLARE
	i_userid    UUID = i_deviceid;

BEGIN

	-- Добавляем устройство, если его еще не существует
	-- Если ID устройства еще нет в БД
	IF NOT EXISTS(SELECT recid
				  FROM devices
				  WHERE recid = i_deviceid)
	THEN

		-- Добавляем нового пользователя
		INSERT INTO users (recid, recname, reccreated) SELECT
						   i_userid,
						   'Zaycev2019',
						   now()
		WHERE NOT EXISTS(SELECT recid FROM users WHERE recid = i_userid);

		-- Добавляем новое устройство
		INSERT INTO devices (recid, userid, recname, reccreated) SELECT
							 i_deviceid,
							 i_userid,
							 'Zaycev2019',
							 now();
	ELSE
		SELECT (SELECT userid
				FROM devices
				WHERE recid = i_deviceid
				LIMIT 1)
		INTO i_userid;
	END IF;

	-- Добавляем трек в базу данных
	INSERT INTO tracks (recid, localdevicepathupload, path, deviceid, reccreated, iscensorial, isexist, outerguid, outersource, artist, recname, length)
	VALUES (i_trackid, i_localdevicepathupload, i_path, i_deviceid, now(), true, 1, i_outerguid, i_outersource, i_artist, i_recname, i_length);


	RETURN TRUE;
END;
 $function$
;
