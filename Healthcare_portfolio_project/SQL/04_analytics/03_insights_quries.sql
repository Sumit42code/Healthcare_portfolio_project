/*
Insights Related queries 
*/

/*Find the lowest and highest referral month in each year.*/

WITH monthly_referrals AS (
    SELECT
        DATE_TRUNC('month', referral_date)::DATE
            AS referral_month,

        COUNT(*) AS total_referrals

    FROM analytics.vw_referral_analysis

    GROUP BY
        DATE_TRUNC('month', referral_date)::DATE
),

ranked_months AS (
    SELECT
        referral_month,
        total_referrals,

        DENSE_RANK() OVER (
            PARTITION BY EXTRACT(YEAR FROM referral_month)
            ORDER BY total_referrals
        ) AS lowest_rank,

        DENSE_RANK() OVER (
            PARTITION BY EXTRACT(YEAR FROM referral_month)
            ORDER BY total_referrals DESC
        ) AS highest_rank

    FROM monthly_referrals
)

SELECT
    EXTRACT(YEAR FROM referral_month)::INTEGER
        AS referral_year,

    TO_CHAR(referral_month, 'Month')
        AS referral_month,

    total_referrals,

    CASE
        WHEN highest_rank = 1 THEN 'Highest'
        WHEN lowest_rank = 1 THEN 'Lowest'
    END AS result_type

FROM ranked_months

WHERE highest_rank = 1
   OR lowest_rank = 1

ORDER BY
    referral_year,
    total_referrals DESC;

/* What is the overall referral status composition?*/

SELECT
    referral_status,

    COUNT(*) AS total_referrals,

    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS share_percentage

FROM analytics.vw_referral_analysis

GROUP BY referral_status

ORDER BY total_referrals DESC;

/* Calculate the overall referral backlog across the network. */

SELECT
 /* All referrals currently classified as backlog. */
    COUNT(*) AS total_backlog_referrals,

    /* Backlog referrals with enough information to calculate a waiting-time target.*/
    COUNT(*) FILTER (
    WHERE backlog_over_target_flag IS NOT NULL) AS target_eligible_referrals,

/* Eligible backlog referrals that exceeded their waiting-time target. */
    COUNT(*) FILTER (
        WHERE backlog_over_target_flag = TRUE
    ) AS referrals_over_target,

/* Percentage of eligible referrals over target. */
    ROUND(COUNT(*) FILTER (
        WHERE backlog_over_target_flag = TRUE) * 100.0
        /
        NULLIF(COUNT(*) FILTER (WHERE backlog_over_target_flag IS NOT NULL),0),2) AS network_over_target_percentage

FROM analytics.vw_referral_analysis

WHERE backlog_flag = TRUE;


