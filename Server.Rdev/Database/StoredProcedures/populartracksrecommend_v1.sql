CREATE OR REPLACE FUNCTION public.populartracksrecommend_v1(i_userid uuid, OUT o_trackid uuid, OUT o_textinfo character varying)
 RETURNS record
 LANGUAGE plpgsql
AS $function$

-- Функция выдачи треков пользователю, не имеющему пользователей со схожим вкусом
BEGIN

	WITH exclude_users AS (
		SELECT r.userid 
			FROM downloadtracks d
				INNER JOIN ratings r
					ON d.trackid = r.trackid
			WHERE d.userid = i_userid
				AND r.userid IN (SELECT recid FROM users WHERE experience >= 10)
			GROUP BY r.userid)
	SELECT recid, 'предрекомендация, суммарный рейтинг трека ' || rate INTO o_trackid, o_textinfo 
		FROM (
		SELECT t.recid, SUM(r.ratingsum) AS rate
			FROM tracks t
				INNER JOIN ratings r
					ON t.recid = r.trackid    
						AND r.userid IN (SELECT recid FROM users WHERE experience >= 10)
			WHERE t.recid NOT IN (SELECT trackid FROM ratings WHERE userid IN (SELECT * FROM exclude_users) GROUP BY trackid)
				AND isexist = 1
				AND (iscorrect IS NULL OR iscorrect <> false)
				AND (iscensorial IS NULL OR iscensorial != false)
				AND (length > 120 OR length IS NULL)
			GROUP BY t.recid
			ORDER BY rate DESC) AS res
		WHERE rate > 0
		LIMIT 1;
END;

$function$
;
