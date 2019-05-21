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
		
-- 		�������� ���������� �� ���������� device_id � ��
		SELECT
			public.devices.recid
		INTO deviceid
		FROM public.devices
		WHERE public.devices.recid = CAST(device_id AS UUID);
-- 			���� ���������� ������� � ��, ��������� ������ �� ������������ � email
		IF deviceid IS NOT NULL THEN
			-- 	��������� id ������������ � emailom
			SELECT 
				users.recid
			INTO useruuid
			FROM public.users
			WHERE public.users.email = googleemail;
-- 			���� ������������ � ����� e-mailom ������, ������������� ��� id ��� ����������
			IF useruuid IS NOT NULL THEN
				UPDATE public.devices SET userid = useruuid WHERE recid = deviceid;
				userid := useruuid;
				success := True;
			ELSE
-- 			����� ��������� email � idtoken ������������, ���������� ���� �����������
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
