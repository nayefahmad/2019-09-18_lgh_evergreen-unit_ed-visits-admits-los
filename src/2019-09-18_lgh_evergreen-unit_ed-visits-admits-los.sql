

/* -----------------------------------------------------------------
LGH ED and Acute usage by patients in Evergreen 
2019-11-05
Nayef 

*/ -----------------------------------------------------------------


drop table if exists #t1_evergreen; 
drop table if exists #t2_ed; 
drop table if exists #t3_ad; 


-- pull patients in Evergreen from PARIS intervention: 
SELECT [PatientID]
      ,[InterventionDateFrom]
	  ,case when [InterventionDateTo] is NULL THEN GETDATE() else InterventionDateTo end as [InterventionDateTo]
      ,[InterventionTeam]
      ,[InterventionDept]
      ,[CommunityLHA]
      ,[CommunityRegion]
      ,[CommunityProgram]
      ,[CommunityProgramGroup]
      ,[InterventionCode]
      ,[InterventionDesc]
      ,[InterventionTypeDesc]
      ,[ExternalProvider]
into #t1_evergreen
FROM [CommunityMart].[dbo].[vwPARISIntervention]
where CommunityRegion = 'Coastal Urban' 
	and ExternalProvider like 'Evergreen%' 
	and InterventionDateFrom >= '2014-01-01' 
order by InterventionDateFrom

-- result 
select * from #t1_evergreen order by interventionDateFrom, patientId



-- now join with ED data: 
select ROW_NUMBER() over(order by InterventionDateFrom, t1.patientID) as ed_visit_identifier
	, t1.PatientID
	, t2_ed.PatientID as [ed_patient_id]
	
	, t1.InterventionDateFrom
	, t2_ed.StartDate
	, t2_ed.DispositionDate
	, t1.InterventionDateTo

	, ExternalProvider

	, t2_ed.[FacilityShortName] as ed_facility
from #t1_evergreen t1
	inner join EDMart.dbo.vwEDVisitIdentifiedRegional t2_ed
	on t1.PatientID = t2_ed.PatientID
	and StartDate between InterventionDateFrom and InterventionDateTo 
where t2_ed.FacilityShortName = 'LGH' 
order by InterventionDateFrom



-- next, join t1_evergreen with acute data: 
select ROW_NUMBER() over(order by InterventionDateFrom, t1.patientID) as acute_stay_identifier
	,  t1.PatientID
	, t3_ad.PatientID as [ad_patient_id]
	, t3_ad.AccountNumber
	
	, t1.InterventionDateFrom
	, t3_ad.AdjustedAdmissionDate
	, t3_ad.AdjustedDischargeDate
	, t1.InterventionDateTo

	, t3_ad.AdmissionNursingUnit
	, t3_ad.DischargeNursingUnit
	, ExternalProvider
	, t3_ad.LOSDays

	, t3_ad.[AdmissionFacilityLongName] as ad_facility
from #t1_evergreen t1
	inner join ADTCMart.ADTC.AdmissionDischargeView t3_ad
	on t1.PatientID = t3_ad.PatientID
	and AdjustedAdmissionDate between InterventionDateFrom and InterventionDateTo 
WHERE AdmissionNursingUnit not like 'EGH%'
	and AdmissionFacilityLongName = 'Lions Gate Hospital' 
order by InterventionDateFrom
