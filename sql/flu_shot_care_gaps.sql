-- Flu Shot Care Gap Analysis: Member List (Measurement Year 2025)
--
-- Purpose: one row per eligible member with a 1/0 flu shot flag.
-- This is the data source for the Tableau dashboard.
--
-- Eligibility rules:
--   Active member: at least one encounter between 2023-01-01 and 2025-12-31
--   Alive: no death date
--   At least 6 months old by 2025-12-31 (CDC: everyone 6 months and older
--   should get a flu shot every year)

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
