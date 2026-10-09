-- ============================================================
-- Flu Shot Care Gap Analysis: Overall Summary (Measurement Year 2025)
-- ============================================================
--
-- What this file does:
-- Collapses the member list into one row with four numbers:
-- eligible members, vaccinated members, members missing a shot,
-- and the overall vaccination rate. I use it to validate the
-- dashboard: every chart must agree with these numbers.
--
-- Expected result: 801 eligible, 116 vaccinated, 685 missing, 14.5%
--
-- How it works:
-- Uses the same three CTEs as flu_shot_care_gaps.sql
-- (active_patients, flu_shot_2025, member_list), so both files
-- apply identical eligibility rules.
--
-- Final select:
-- count(*)                  total eligible members
-- sum(flu_shot_2025)        vaccinated members (0s add nothing)
-- count(*) - sum(...)       members missing a flu shot
-- round(100.0 * ... , 1)    rate as a percent; 100.0 forces decimal
--                           division, since whole number division
--                           in PostgreSQL drops the decimals
-- ============================================================

with active_patients as (
  select distinct e.patient
  from encounters as e
  join patients as pt
    on e.patient = pt.id
  where e.start between '2023-01-01 00:00' and '2025-12-31 23:59'
    and pt.deathdate is null
    -- birthdate filter instead of extract(month from age(...)):
    -- extract only reads the months part, so a 40 year 4 month old would fail
    and pt.birthdate <= date '2025-12-31' - interval '6 months'
),

flu_shot_2025 as (
  -- one row per member: a member can get more than one shot in a year,
  -- which would duplicate rows in the join below
  select patient, min(date) as earliest_flu_shot_2025
  from immunizations
  where code = '140'
    and date between '2025-01-01 00:00' and '2025-12-31 23:59'
  group by patient
),

member_list as (
  -- one row per eligible member with a 1/0 vaccination flag
  -- left join keeps unvaccinated members (they are the care gaps)
  select
    pt.id,
    pt.first,
    pt.last,
    pt.race,
    pt.county,
    pt.birthdate,
    extract(year from age(date '2025-12-31', pt.birthdate)) as age_2025,
    flu.earliest_flu_shot_2025,
    case when flu.patient is not null then 1 else 0 end as flu_shot_2025
  from patients as pt
  left join flu_shot_2025 as flu
    on pt.id = flu.patient
  where pt.id in (select patient from active_patients)
)

select
  count(*) as eligible_members,
  sum(flu_shot_2025) as vaccinated,
  count(*) - sum(flu_shot_2025) as not_vaccinated,
  -- 100.0 forces decimal division; whole number division drops decimals
  round(100.0 * sum(flu_shot_2025) / count(*), 1) as vaccination_rate_pct
from member_list;
