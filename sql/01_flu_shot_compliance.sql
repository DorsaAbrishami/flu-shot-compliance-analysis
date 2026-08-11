with flu_shot_2022 as 
(select patient, min(date) as earliest_flu_shot_2022
from immunizations
where code = '140' and date between '2022-01-01 00:00' and '2022-12-31 23:59'
group by patient )
select pt.race, pt.birthdate,pt.county, pt.id, pt.first, pt.last  
from patients as pt
left join flu_shot_2022 
on pt.id = flu_shot_2022.patient;



 