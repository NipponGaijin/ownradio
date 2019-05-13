CREATE OR REPLACE FUNCTION public.updateratios(i_userid uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
-- функция обновляет таблицу коэффециентов схожести интересов для всех пользователей, прослушавших те же треки, что и i_userid
DECLARE
	cuser1 uuid;
	cuser2 uuid;
	cratio integer;
BEGIN

-- 	RETURN true;
	
	DROP TABLE IF EXISTS temp_ratio;
	CREATE TEMP TABLE temp_ratio(userid1 uuid, userid2 uuid, ratio integer);

	-- рассчитываем матрицу коэффициентов схожести интересов для каждой пары пользователей
	INSERT INTO temp_ratio(userid1, userid2, ratio)
			(SELECT r.userid as userid01, r2.userid as userid02, --SUM(r.ratingsum * r2.ratingsum) as s
				-- считаем сумму произведений с учетом весов коэффициентиов: ratingsum<0 => weight=1, ratingsum>0 => weight=3
				-- SUM(CASE WHEN r.ratingsum > 0 AND r2.ratingsum > 0 THEN r.ratingsum * r2.ratingsum * 3

				SUM(r.ratingsum * r2.ratingsum) as S
				-- было решено не учитывать пропущенные треки вообще, поэтому условие case было заменено на проверку в блоке where
				-- SUM(CASE WHEN r.ratingsum > 0 AND r2.ratingsum > 0 THEN r.ratingsum * r2.ratingsum
-- 					WHEN r.ratingsum < 0 AND r2.ratingsum < 0 THEN 0
-- 					ELSE r.ratingsum * r2.ratingsum
-- 					END) as S
				FROM ratings r
					INNER JOIN ratings r2 ON r.trackid = r2.trackid
						   AND r.userid != r2.userid
						   AND ((r.userid = i_userid AND r2.userid IN (SELECT recid FROM users WHERE experience >= 10)) 
								OR (r2.userid = i_userid AND r.userid IN (SELECT recid FROM users WHERE experience >= 10)))
				WHERE r.ratingsum > 0 AND r2.ratingsum > 0
				GROUP BY r.userid, r2.userid);

	-- обновляем ratio, если пара пользователей уже была в таблице
	UPDATE ratios SET ratio = temp_ratio.ratio, recupdated = now() FROM temp_ratio
		WHERE ratios.userid1 = temp_ratio.userid1 AND ratios.userid2 = temp_ratio.userid2;

	-- Добавляем записи для новой пары с пользователейм
	INSERT INTO ratios (userid1, userid2, ratio, reccreated)
		(SELECT temp_ratio.userid1,temp_ratio.userid2, temp_ratio.ratio, now() 
			FROM temp_ratio
			LEFT OUTER JOIN ratios ON 
				temp_ratio.userid1 = ratios.userid1 AND temp_ratio.userid2 = ratios.userid2
			WHERE ratios.userid1 IS NULL OR ratios.userid2 IS NULL
		);

RETURN TRUE;
END;
$function$
;
