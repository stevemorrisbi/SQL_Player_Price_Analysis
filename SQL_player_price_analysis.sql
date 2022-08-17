-- Exploring the data --
-- Ranking all highest valued players in the world by overall rank and their country rank 
SELECT pretty_name AS player_name
	, market_value_in_gbp AS value
	, position
	, country_of_citizenship AS country
	, DENSE_RANK () OVER (ORDER BY market_value_in_gbp DESC) AS overall_rank
	, DENSE_RANK() OVER (PARTITION BY country_of_citizenship ORDER BY market_value_in_gbp DESC) AS country_rank
FROM [dbo].[players 3]
WHERE country_of_citizenship IS NOT NULL
ORDER BY highest_market_value_in_gbp DESC

--Exploring the data --
-- Highest valued players in the Premier League in 2022
SELECT *
FROM [dbo].[players 3]
WHERE last_season = '2022'
ORDER BY market_value_in_gbp DESC

-- Joining tables to include name of the club and goals/assists
SELECT p.pretty_name player
		, market_value_in_gbp mv
		, c.pretty_name club
		, SUM(a.goals) goals_total
		, SUM(a.assists) asists_total
FROM [dbo].[players 3] p
INNER JOIN [dbo].[clubs] c ON p.current_club_id  = c.club_id
INNER JOIN [dbo].[appearances] a ON p.player_id  = a.player_id
WHERE last_season = '2022'
GROUP BY p.pretty_name, market_value_in_gbp, c.pretty_name
ORDER BY market_value_in_gbp DESC, SUM(a.goals) DESC

-- adding price grouping into above query
SELECT p.pretty_name player
		, market_value_in_gbp mv
		, c.pretty_name club
		, SUM(a.goals) goals_total
		, SUM(a.assists) asists_total
		, CASE 
		WHEN market_value_in_gbp <= 25000000 THEN 'low price'
		WHEN market_value_in_gbp <= 50000000 THEN 'medium price'
		WHEN market_value_in_gbp <= 80000000 THEN 'high price'
		WHEN market_value_in_gbp > 80000000 THEN 'very high price'
		ELSE 'no rating'
		END AS price_rating 
FROM [dbo].[players 3] p
INNER JOIN [dbo].[clubs] c ON p.current_club_id  = c.club_id
INNER JOIN [dbo].[appearances] a ON p.player_id  = a.player_id
WHERE last_season = '2022'
GROUP BY p.pretty_name, market_value_in_gbp, c.pretty_name
ORDER BY market_value_in_gbp DESC, SUM(a.goals) DESC

-- find out total number of Liverpool players with a price rating of 'high'
WITH price_rating_cte
AS
(
SELECT p.pretty_name player
		, market_value_in_gbp mv
		, c.pretty_name club
		, SUM(a.goals) goals_total
		, SUM(a.assists) assists_total
		, CASE 
		WHEN market_value_in_gbp <= 25000000 THEN 'low price'
		WHEN market_value_in_gbp <= 50000000 THEN 'medium price'
		WHEN market_value_in_gbp <= 80000000 THEN 'high price'
		WHEN market_value_in_gbp > 80000000 THEN 'very high price'
		ELSE 'no rating'
		END AS price_rating 
FROM [dbo].[players 3] p
INNER JOIN [dbo].[clubs] c ON p.current_club_id  = c.club_id
INNER JOIN [dbo].[appearances] a ON p.player_id  = a.player_id
WHERE last_season = '2022'
GROUP BY p.pretty_name, market_value_in_gbp, c.pretty_name
),
liverpool_cte AS
(
SELECT player
       , mv
	   , goals_total
	   , price_rating
	   , COUNT(price_rating) OVER (PARTITION BY price_rating ORDER BY mv DESC) AS group_count
FROM price_rating_cte
WHERE club LIKE '%Liverpool'
GROUP BY player, price_rating, mv, goals_total
),
liverpool_group_cte AS
(
SELECT price_rating, MAX(group_count) AS group_count,
CASE 
	WHEN price_rating = 'low price' THEN 0
	WHEN price_rating = 'medium price' THEN 1
	WHEN price_rating = 'high price' THEN 2
	WHEN price_rating = 'very high price' THEN 3
	END AS price_order
FROM liverpool_cte
GROUP BY price_rating
)
SELECT price_rating, group_count
FROM liverpool_group_cte
ORDER BY price_order
-- Above uses multiple CTE's to rank liverpool players into price groups.
-- The players are then counted up the price groups in a customised order - low to very high.
-- multiple case statements where needed for the price groupings and then the customised order.

-- Developing the above query to compare Liverpool to Arsenal.
-- Will need to use a Self Join on price rating the same but club not the same.
-- output should be arsenal team name / rating / count / liverpool team / rating / count 

WITH price_rating_cte
AS
(
SELECT p.pretty_name player
		, market_value_in_gbp mv
		, c.pretty_name club
		, SUM(a.goals) goals_total
		, SUM(a.assists) assists_total
		, CASE 
		WHEN market_value_in_gbp <= 25000000 THEN 'low price'
		WHEN market_value_in_gbp <= 50000000 THEN 'medium price'
		WHEN market_value_in_gbp <= 80000000 THEN 'high price'
		WHEN market_value_in_gbp > 80000000 THEN 'very high price'
		ELSE 'no rating'
		END AS price_rating 
FROM [dbo].[players 3] p
INNER JOIN [dbo].[clubs] c ON p.current_club_id  = c.club_id
INNER JOIN [dbo].[appearances] a ON p.player_id  = a.player_id
WHERE last_season = '2022'
GROUP BY p.pretty_name, market_value_in_gbp, c.pretty_name
),
liverpool_cte AS
(
SELECT player
		, club
		, mv
		, goals_total
		, price_rating
		, COUNT(price_rating) OVER (PARTITION BY price_rating
		, club ORDER BY mv DESC) AS group_count
FROM price_rating_cte
WHERE (club LIKE '%Arsenal') OR (club LIKE '%Liverpool')
GROUP BY player, price_rating, mv, goals_total, club
),
--SELECT * FROM liverpool_cte
--WHERE (club LIKE '%Arsenal') OR (club LIKE '%Liverpool')
liverpool_group_cte AS
(
SELECT club
		, price_rating
		, MAX(group_count) AS total_count,
CASE 
	WHEN price_rating = 'low price' THEN 0
	WHEN price_rating = 'medium price' THEN 1
	WHEN price_rating = 'high price' THEN 2
	WHEN price_rating = 'very high price' THEN 3
	END AS price_order
FROM liverpool_cte
GROUP BY price_rating, club 
) ,
end_cte
AS
(
SELECT a.club club_1
		, a.price_rating price_rating_1
		, a.total_count total_1
		, l.club club_2
		, l.price_rating price_rating_2
		, l.total_count total_2
		, a.price_order price_order_2,
ROW_NUMBER() OVER(ORDER BY l.price_order) AS RowNumber
FROM liverpool_group_cte l
RIGHT JOIN liverpool_group_cte a ON l.club <> a.club
AND a.price_rating = l.price_rating 
)
SELECT club_1
		, price_rating_1
		, total_1
		, club_2
		, price_rating_2
		, total_2
FROM end_cte
WHERE RowNumber % 2 = 1
ORDER BY price_order_2

-- Right join used to get the nulls on the right hand side of the table and not in the left.
-- where row number is odd is used to filter out the duplication of identical rows in the columns.
-- the very high price row is not a duplication and falls in an odd row. hence keeping all odd rows.
-- edge case -- If the two teams matched with number of rows then remove even rows.
-- edge case for missing values in even and odd rows would have to be considered later. 
-- could turn club names into variables to created a comparison tool stored procedure. 
-- Ordered by the Liverpool price order because very high price not in the Arsenal table.
-- Could clean the end output by editing team names.
-- Could replace null with / Arsenal / very high price / 0 

-- extra notes - players have a player id but players repeat multiple times in the table. 
-- Joining on player i.d would need to join on the latest entry of the player id from 2022.

-- SUM(total_1) OVER () AS Squad_Total ---- This would give the Liverpool squad total Over()nothing means over all data. 
