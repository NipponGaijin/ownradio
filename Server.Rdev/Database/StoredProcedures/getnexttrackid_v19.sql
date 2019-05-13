CREATE OR REPLACE FUNCTION public.getnexttrackid_v19(i_deviceid uuid)
 RETURNS TABLE(track uuid, methodid integer, useridrecommended uuid, txtrecommendedinfo character varying)
 LANGUAGE plpgsql
AS $function$

-- Функция выдачи треков пользователю
DECLARE
	i_userid   UUID ;
	rnd        INTEGER = (SELECT trunc(random() * 1001)); -- генерируем случайное целое число в диапазоне от 1 до 1000
	o_methodid INTEGER; -- id метода выбора трека
	owntracks  INTEGER; -- количество "своих" треков пользователя (обрезаем на 900 шт)
	arrusers uuid ARRAY; -- массив пользователей для i_userid с неотрицательнымм коэффициентами схожести интересов
	exceptusers uuid ARRAY; -- массив пользователей для i_userid с котороми не было пересечений по трекам
	temp_trackid uuid; 
	tmp_txtrecommendinfo text;
begin
	
	--получаем id пользователя по id устройства
	 select userid into i_userid from devices where devices.recid = i_deviceid;

	-- temp_track - временная таблица для промежуточного результата (понадобилась чтобы найденные данные сначала сохранять в таблицу downloadtracks, а потом возвращать
	DROP TABLE IF EXISTS temp_track; 
	CREATE TEMP TABLE temp_track(track uuid, methodid integer, useridrecommended uuid, txtrecommendedinfo character varying);-- 

	--Если устройство не было зарегистрировано ранее - регистрируем его
	IF NOT EXISTS(SELECT recid
		  FROM devices
		  WHERE recid = i_deviceid)
	THEN

		-- Добавляем нового пользователя
		INSERT INTO users (recid, recname, reccreated) SELECT
						   i_userid,
						   'New user recname',
						   now()
		WHERE NOT EXISTS(SELECT recid FROM users WHERE recid = i_userid);

		-- Добавляем новое устройство
		INSERT INTO devices (recid, userid, recname, reccreated) SELECT
							 i_deviceid,
							 i_userid,
							 'New device recname',
							 now();
	ELSE
	-- Если устройство зарегистрировано - ищем соответствующего ему пользователя
		SELECT (SELECT userid
				FROM devices
				WHERE recid = i_deviceid
				LIMIT 1)
		INTO i_userid;
	END IF;


	-- Выбираем следующий трек

	-- Определяем количество "своих" треков пользователя
	owntracks = (SELECT COUNT(*)
				FROM ratings
					WHERE userid = i_userid
						AND ratingsum >= 0);

	-- Если количество "своих" треков = 0 - выполняем процедуру предрекомендации
	IF (owntracks = 0) THEN
		o_methodid = 8; -- метод выбора из рекомендованных треков
		SELECT o_trackid, o_textinfo INTO temp_trackid, tmp_txtrecommendinfo FROM populartracksrecommend_v1(i_userid);
		-- Если такой трек найден - запись информацию о нем в downloadtracks, выход из функции, возврат найденного значения
		IF temp_trackid IS NOT null THEN
			INSERT INTO downloadtracks (recid, reccreated,deviceid, trackid, methodid, txtrecommendinfo, userrecommend, userid)
				VALUES (uuid_generate_v4(),
							now(),
							i_deviceid,
							temp_trackid,
							o_methodid,
							(SELECT CAST((tmp_txtrecommendinfo) AS CHARACTER VARYING)),
							(SELECT CAST((null) AS UUID)),
							 i_userid);
		RETURN QUERY 
			SELECT temp_trackid,
			o_methodid,
			(SELECT CAST((null) AS UUID)),
			(SELECT CAST((
				tmp_txtrecommendinfo
				) AS CHARACTER VARYING));
		RETURN;
		END IF;
	END IF;
-- 	IF (rnd < owntracks)
-- 	THEN
-- 		o_methodid = 2; -- метод выбора из своих треков
-- 		INSERT INTO temp_track (
-- 		SELECT
-- 			trackid, -- выбираем id трека
-- 			o_methodid,
-- 			(SELECT CAST((null) AS UUID)),
-- 			(SELECT CAST(('случайный трек из своих') AS CHARACTER VARYING))
-- 		FROM ratings -- из треков, имеющих рейтинг для данного пользователя
-- 		WHERE userid = i_userid
-- 			  AND lastlisten < localtimestamp - INTERVAL '1 day' -- для которого последнее прослушивание было ранее, чем за сутки до выдачи
-- 			  AND ratingsum >= 0 -- рейтинг трека неотрицательный
-- 			  AND (SELECT isexist
-- 				   FROM tracks
-- 				   WHERE recid = trackid) = 1 -- трек существует на сервере
-- 			  AND ((SELECT length
-- 					FROM tracks
-- 					WHERE recid = trackid) >= 120 -- продолжительность трека больше двух минут
-- 				   OR (SELECT length
-- 					   FROM tracks
-- 					   WHERE recid = trackid) IS NULL) -- или длина трека не известна
-- 			  AND ((SELECT iscensorial
-- 					FROM tracks
-- 					WHERE recid = trackid) IS NULL -- трек должен быть цензурный или непроверенный
-- 				   OR (SELECT iscensorial
-- 					   FROM tracks
-- 					   WHERE recid = trackid) != 0)
-- 			  AND trackid NOT IN (SELECT trackid
-- 								  FROM downloadtracks
-- 								  WHERE reccreated > localtimestamp - INTERVAL '1 week' AND deviceid = i_deviceid) -- трек недолжен быть выдан в последнюю неделю
-- 		ORDER BY RANDOM()
-- 		LIMIT 1);

-- 		-- Если такой трек найден - запись информацию о нем в downloadtracks, выход из функции, возврат найденного значения
-- 		IF FOUND THEN
-- 			INSERT INTO downloadtracks (SELECT uuid_generate_v4(),now(),null, null, i_userid, temp_track.track AS trackid, temp_track.methodid AS methodid, temp_track.txtrecommendedinfo AS txtrecommendinfo, temp_track.useridrecommended AS userrecommend FROM temp_track);
-- 			RETURN QUERY SELECT * FROM temp_track;
-- 			RETURN;
-- 		END IF;
-- 	END IF;

	-- Если rnd больше количества "своих" треков - используем алгоритм рекоммендаций

	-- Если положительный коэффициент схожести интересов больше чем с пятью пользователями,
-- 	IF (SELECT COUNT (*) FROM ratios WHERE (userid1 = i_userid OR userid2 = i_userid) AND ratio >=0) > 5 THEN
	-- рекомендуем трек с максимальным рейтингом среди пользователей, с которыми были пересечения
		o_methodid = 7; -- метод выбора из рекомендованных треков
		SELECT rn_trackid, rn_txtrecommendinfo INTO temp_trackid, tmp_txtrecommendinfo FROM getrecommendedtrackid_v5(i_userid);
		-- Если такой трек найден - запись информацию о нем в downloadtracks, выход из функции, возврат найденного значения
		IF temp_trackid IS NOT null THEN
			INSERT INTO downloadtracks (recid, reccreated,deviceid, trackid, methodid, txtrecommendinfo, userrecommend, userid)
				VALUES (uuid_generate_v4(),
							now(),
							i_deviceid,
							temp_trackid,
							o_methodid,
							(SELECT CAST((tmp_txtrecommendinfo) AS CHARACTER VARYING)),
							(SELECT CAST((null) AS UUID)),
							 i_userid);
		RETURN QUERY 
			SELECT temp_trackid,
			o_methodid,
			(SELECT CAST((null) AS UUID)),
			(SELECT CAST((
				tmp_txtrecommendinfo
				) AS CHARACTER VARYING));
		RETURN;
		END IF;
-- 	END IF;

	-- Если таких треков нет - выбираем популярный трек из ни разу не прослушанных пользователем треков
	o_methodid = 3; -- метод выбора популярных из непрослушанных треков
	INSERT INTO temp_track (
	SELECT
		trackid,
		o_methodid,
		(SELECT CAST((null) AS UUID)),
		(SELECT CAST(('популярный трек из непрослушанных пользователем') AS CHARACTER VARYING))
		FROM ratings
			WHERE userid IN (SELECT recid FROM users WHERE experience >= 10)
				AND userid != i_userid
				AND (SELECT recid FROM tracks 
						WHERE recid = trackid
							AND isexist = 1 -- трек существует на сервере
							AND (iscorrect IS NULL OR iscorrect != false)
							AND (length >= 120 OR length IS NULL) -- продолжительность трека больше двух минут или длина трека не известна
							AND (iscensorial != false OR iscensorial IS NULL)) IS NOT NULL --трек должен быть цензурный или непроверенный
				AND trackid NOT IN (SELECT trackid
							FROM downloadtracks
							WHERE deviceid = i_deviceid)


		GROUP BY trackid
		ORDER BY sum(ratingsum) DESC, RANDOM()
		LIMIT 1);

	-- Если такой трек найден - запись информацию о нем в downloadtracks, выход из функции, возврат найденного значения
	IF FOUND THEN
		INSERT INTO downloadtracks (recid, reccreated,deviceid, trackid, methodid, txtrecommendinfo, userrecommend, userid)
				VALUES (uuid_generate_v4(),
							now(),
							i_deviceid,
							(select temp_track.track from temp_track),
							o_methodid,
							(SELECT CAST((temp_track.txtrecommendedinfo) AS CHARACTER VARYING) from temp_track),
							(SELECT CAST((temp_track.useridrecommended) AS UUID) from temp_track),
							 i_userid );
		RETURN QUERY SELECT * FROM temp_track;
		RETURN;
	END IF;

	-- Если предыдущие запросы вернули null, выбираем случайный трек
	o_methodid = 1; -- метод выбора случайного трека
	INSERT INTO temp_track (
	SELECT
		recid,
		o_methodid,
		(SELECT CAST((null) AS UUID)),
		(SELECT CAST(('случайный трек из всех') AS CHARACTER VARYING))
	FROM tracks
	WHERE isexist = 1 -- существующий на сервере 
		AND (iscorrect IS NULL OR iscorrect != false)
		  AND (iscensorial IS NULL OR iscensorial != false) -- цензурный
		  AND (length > 120 OR length IS NULL) -- продолжительностью более 2х минут.
	ORDER BY RANDOM()
	LIMIT 1);
	INSERT INTO downloadtracks (recid, reccreated,deviceid, trackid, methodid, txtrecommendinfo, userrecommend, userid)
			VALUES (uuid_generate_v4(),
						now(),
						i_deviceid,
						(select temp_track.track from temp_track),
						o_methodid,
						(SELECT CAST((temp_track.txtrecommendedinfo) AS CHARACTER VARYING) from temp_track),
						(SELECT CAST((temp_track.useridrecommended) AS UUID) from temp_track),
						 i_userid );
	RETURN QUERY SELECT * FROM temp_track;
	RETURN;
END;
$function$
;
