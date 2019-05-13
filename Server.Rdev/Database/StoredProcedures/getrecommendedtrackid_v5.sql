CREATE OR REPLACE FUNCTION public.getrecommendedtrackid_v5(in_userid uuid)
 RETURNS TABLE(rn_trackid uuid, rn_txtrecommendinfo text)
 LANGUAGE plpgsql
AS $function$

DECLARE 
rnd DOUBLE PRECISION;
execution_start_time TIMESTAMP;
tracks_with_sum_rates_created_time TIMESTAMP;
rnd_generated_time TIMESTAMP;

tracks_with_sum_rates_creation_time_txt TEXT;
rnd_generation_time_txt TEXT;

BEGIN
	--Время начала выполнения тела функции
	SELECT timeofday()::timestamp INTO execution_start_time;

	DROP TABLE IF EXISTS tracks_with_sum_rates;
	CREATE TEMP TABLE tracks_with_sum_rates
	AS
	-- Соединяем таблицу tracks с таблицой сумм произведений рейтинга трека на коэффициент
		-- у конкретного пользователя для возможности вывода дополнительной информации о треке
		-- в отладочных целях и для фильтра по столбцам tracks
		SELECT tracks.recid AS track_id, tracks_sum_rates.sum_rate AS track_sum_rate-- INTO preferenced_track
		--tracks.recid, tracks_sum_rates.sum_rate, tracks.localdevicepathupload, tracks.path
					FROM tracks
					INNER JOIN (
						--Группируем по треку и считаем сумму произведений рейтингов на коэффициент для
						--каждого из них
						SELECT trackid, SUM(track_rating) AS sum_rate
						FROM(
							--Запрашиваем таблицу с рейтингом всех треков, оцененных пользователями, которые имеют коэффициент
							--с исходным, умноженным на их коэффициент
							SELECT ratings.trackid, ratings.ratingsum * experts_ratios.ratio AS track_rating, ratings.userid--, ratios.ratio
							FROM ratings
								INNER JOIN
								(
									--Соединим таблицу коэффициентов совпадения вкусов исходного пользователя с экспертами
									--с таблицой с UUID'ми всех экспертов.
									--Если у исходного пользователя нет пересечения с каким-либо экспертом, то вернем 1 в
									--качестве коэффициента
									SELECT COALESCE(associated_experts.ratio, 0.7) AS ratio, all_experts.userid AS expert_id
									FROM
									(
										--Выберем коэффициенты исходно пользователя с кем-либо из экспертов
										--и UUID'ы этих экспертов
										SELECT ratios.ratio AS ratio, ratios.userid2 AS userid
										FROM ratios
										WHERE ratios.userid1 = in_userid AND ratios.userid2 IN (SELECT recid FROM users WHERE experience >= 10)
									) AS associated_experts
									RIGHT JOIN 
									(
										--Выберем UUID'ы всех экспертов
										SELECT recid AS userid
										FROM users
										WHERE experience >= 10
									) AS all_experts
									ON associated_experts.userid = all_experts.userid
								) AS experts_ratios
								ON ratings.userid = experts_ratios.expert_id-- AND ratios.userid1 = in_userid
								AND ratings.userid <> in_userid --Выбирем все оценки треков, кроме оценок, данных исходным пользователем
								AND experts_ratios.ratio > 0 --Считать рейтинги треков, только у пользователей с положительным коэффициентом совпадения вкусов с исходным
						) AS tracks_ratings
						GROUP BY trackid
						ORDER BY sum_rate DESC
					) AS tracks_sum_rates
					ON tracks.recid = tracks_sum_rates.trackid
					AND tracks.isexist = 1 --Трек должен существовать на сервере
					AND (iscorrect IS NULL OR iscorrect <> false) -- Трек не должен быть битым
					AND tracks.iscensorial <> false --Трек не должен быть помечен как нецензурный
					AND tracks.length >= 120
					
					--Трек не должен был выдаваться исходному пользователю в течении последних двух месяцев (пока заменено на условие ниже)
					--AND tracks.recid NOT IN (SELECT trackid FROM downloadtracks
								 --WHERE reccreated > localtimestamp - INTERVAL '2 months' AND deviceid = in_userid)
								 
					--Трек не должен был выдаваться исходному пользователю вообще никогда
					AND tracks.recid NOT IN (SELECT trackid FROM downloadtracks
								 WHERE userid = in_userid)
								 
					AND sum_rate >= 0 --В итоге рекомендоваться будут только треки с положительной суммой произведений рейтингов на коэффициенты
					ORDER BY tracks_sum_rates.sum_rate DESC;


	--Время после создания таблицы tracks_with_sum_rates
	SELECT timeofday()::timestamp INTO tracks_with_sum_rates_created_time;
	
	--От текущего времени отнимаем execution_start_time и приводим к миллисекундам (numeric(18,3)), затем записываем в строковую переменную tracks_with_sum_rates_creation_time
	--Таким образом вычисленно время создания временной таблицы tracks_with_sum_rates
	SELECT (cast(extract(epoch from (tracks_with_sum_rates_created_time - execution_start_time)) as numeric(18,3)))::text INTO tracks_with_sum_rates_creation_time_txt;
				
	--Сгруппируем треки по рейтингу и умножим рандомное число от 0 до 1 на сумму этих рейтингов
	--полученное число запишем в переменную rnd
	--Сумма рейтингов групп треков обозначает общую область вероятности рекомендации трека из какой-либо группы,
	--где сумма рейтингов группы n с рейтингом группы n + 1 (упорядоченных по возрастанию рейтинга) обозначает
	--область вероятности рекомендации трека из группы n + 1
	--Группа, из которой в итоге порекомендуется трек, будет определяется числом в переменной rnd
	SELECT (random() * SUM(groups_by_rate.group_rate)) INTO rnd FROM
	(	--NULLIF возвращает NULL, если rate == 0, а COALESCE возвращает 0.3,
		--если NULLIF вернет NULL, соответственно оператор просто выставляет
		--рейтинг 0.3 трекам с рейтингом 0
		SELECT COALESCE(NULLIF(track_sum_rate, 0), 0.3) AS group_rate FROM tracks_with_sum_rates
		GROUP BY track_sum_rate
		ORDER BY track_sum_rate
	) AS groups_by_rate;

	--Время после генерации rnd
	SELECT timeofday()::timestamp INTO rnd_generated_time;

	--Время, затраченное на генерацию rnd
	SELECT (cast(extract(epoch from (rnd_generated_time - tracks_with_sum_rates_created_time)) as numeric(18,3)))::text INTO rnd_generation_time_txt;

	RETURN QUERY
	(
		--Выберем рандомный трек из группы, отобранной во вложенной запросе
		SELECT track_id, 'getrecommendedtrackid_v5; sum_rate:' || track_sum_rate::text || '; rnd_in_range:' || rnd::text || '; temp_table_creation:' || tracks_with_sum_rates_creation_time_txt || '; rnd_creation:' || rnd_generation_time_txt
		FROM tracks_with_sum_rates
		WHERE track_sum_rate = 
		(
			--Если рейтинг полученной группы окажется равен 0.3, то заменяем на 0
			--т.к. треков с рейтингом 0.3 не существует. Им присваивалось значение 0.3 вместо 0
			--чтобы они так же имели небольшой шанс рекомендоваться для прослушивания
			SELECT COALESCE(NULLIF(groups_by_rate_with_range_max.track_sum_rate, 0.3), 0)
			FROM
			(
			    --Выберем первую группу треков из групп, упорядоченных по возрастанию рейтинга, рейтинг которой окажется больше числа rnd
			    SELECT SUM(groups_by_rate.group_rate) OVER (ORDER BY groups_by_rate.group_rate) AS group_range_max, groups_by_rate.group_rate AS track_sum_rate, rnd as rnd_in_range
			    FROM
			    (
				SELECT COALESCE(NULLIF(track_sum_rate, 0), 0.3) AS group_rate FROM tracks_with_sum_rates
				GROUP BY track_sum_rate
				ORDER BY track_sum_rate
			    ) AS groups_by_rate
			) AS groups_by_rate_with_range_max
			WHERE group_range_max >= rnd
			ORDER BY group_range_max
			LIMIT 1
		)
		ORDER BY random()
		LIMIT 1
	);	
END;
$function$
;
