

#'--- 
#' title: "LGH Evergreen Unit ED visits"
#' author: "Nayef Ahmad"
#' date: "2019-11-13"
#' output: 
#'   html_document: 
#'     keep_md: yes
#'     code_folding: show
#'     toc: true
#'     toc_float:
#'       collapsed: false
#'     toc_folding: false
#' ---
#' 

#+ lib, include = FALSE
library(tidyverse)
library(denodoExtractor)
library(lubridate)

setup_sql_server()
setup_denodo()

#+ rest 


#' first pull data on Evergreen pts from CommunityMart PARISIntervention
#' 
#' 
df1.evergreen <- 
  vw_community_paris_intervention %>% 
  filter(CommunityRegion == "Coastal Urban", 
         InterventionDateFrom > "2014-01-01") %>% 
  select(PatientID, 
         InterventionDateFrom, 
         InterventionDateTo,
         InterventionTeam,
         InterventionDept,
         CommunityLHA,
         CommunityRegion,
         CommunityProgram, 
         InterventionCode,
         InterventionDesc, 
         InterventionTypeDesc,
         ExternalProvider) %>% 
  collect() %>% 
  
  filter(grepl("^Evergreen.*", ExternalProvider)) %>% 
  
  mutate(InterventionDateTo = ifelse(is.na(InterventionDateTo),
                                     as.character(today()), 
                                     InterventionDateTo)) %>% 
  
  mutate(InterventionDateFrom = ymd(InterventionDateFrom),
         InterventionDateTo = ymd(InterventionDateTo)) %>% 
  
  arrange(InterventionDateFrom,
          PatientID)


#' Next pull ED data and acute data
#' 
#' 

df2.ed <- 
  vw_eddata %>% 
  filter(facility_short_name == "LGH", 
         start_date_id >= "20140101") %>% 
  select(patient_id, 
         start_date_id, 
         left_ed_date_id) %>% 
  collect() %>% 
  mutate(start_date = ymd(start_date_id))

df3.acute <- 
  vw_admission_discharge %>% 
  filter(facility_short_name == "LGH", 
         admit_date_id >= "20140101") %>% 
  select(patient_id, 
         admit_date_id, 
         disch_date_id, 
         # nursing_unit_desc_at_ad, 
         nursing_unit_desc_at_admit) %>% 
  collect() %>% 
  mutate(admit_date = ymd(admit_date_id))




#' Inner join Evergreen pts and ED data
#' 

df4.ed_usage <- 
  df1.evergreen %>% 
  inner_join(df2.ed, 
             by = c("PatientID" = "patient_id")) %>% 
  filter(start_date >= InterventionDateFrom, 
         start_date <= InterventionDateTo)



#' Inner join Evergreen pts and acute data
#' 

df5.acute_usage <- 
  df1.evergreen %>% 
  inner_join(df3.acute, 
             by = c("PatientID" = "patient_id")) %>% 
  filter(admit_date >= InterventionDateFrom, 
         admit_date <= InterventionDateTo,
         !grepl("^EGH.*", nursing_unit_desc_at_admit))

