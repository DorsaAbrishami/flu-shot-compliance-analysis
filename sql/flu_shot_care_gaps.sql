
-- Flu Shot Care Gap Analysis: Member List (Measurement Year 2025)
-- ============================================================
--
-- What this file does:
-- Returns one row per eligible member (801 rows) with a 1/0 flag
-- showing whether they got a flu shot in 2025. This is the data
-- source for the Tableau dashboard. Tableau groups these rows by
-- age, race, and county, and averages the 1/0 flag to get each
-- group's vaccination rate (the average of 1s and 0s equals the
-- share of 1s).
--
-- How it works:
-- 1) active_patients: members with at least one visit from
--    2023-01-01 to 2025-12-31, alive, and at least 6 months old
--    by 2025-12-31 (CDC guideline). This is the denominator.
-- 2) flu_shot_2025: members with a flu shot (code 140) in 2025,
--    keeping only the earliest shot so no member is counted twice.
-- 3) member_list: joins the two with a LEFT JOIN so unvaccinated
--    members stay in the data as care gaps, and turns the result
--    into a 1/0 column with CASE.
--
-- Final select: returns every member with their details and flag.
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
  id,
  first,
  last,
  race,
  county,
  birthdate,
  age_2025,
  earliest_flu_shot_2025,
  flu_shot_2025
from member_list;
